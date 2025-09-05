pipeline {
  agent any
  environment {
    APP_NAME         = "nestjs-app"
    PORT             = "3000"
    AWS_REGION       = "us-east-2"
    ACCOUNT_ID       = "825765398232"               // <-- tu cuenta
    ECR_REPO         = "nestjs-app"
    IMAGE_TAG        = "latest"  // tag inmutable recomendado
    IMAGE_URI        = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}"
    TARGET_GROUP_ARN = "arn:aws:elasticloadbalancing:us-east-2:825765398232:targetgroup/testeoecr/bb947db53d3506b5"

    AWS_CREDS        = "jenkins-aws-ecr"
    GITHUB_CREDS     = "GitHub-https-token"
  }

  stages {
    stage('Checkout') {
      steps {
        git url: 'https://github.com/CecomMEX/test-jenkins.git',
            branch: 'main',
            credentialsId: "${GITHUB_CREDS}"
      }
    }

    stage('Docker Build') {
      steps {
        sh 'docker build -t ${IMAGE_URI} .'
      }
    }

    stage('Login & Push to ECR') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${AWS_CREDS}",
                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            set -eux
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
            aws configure set default.region ${AWS_REGION}

            aws ecr describe-repositories --repository-names ${ECR_REPO} >/dev/null 2>&1 || \
              aws ecr create-repository --repository-name ${ECR_REPO}

            aws ecr get-login-password --region ${AWS_REGION} | \
              docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

            docker push ${IMAGE_URI}
          '''
        }
      }
    }

    stage('Rolling Deploy') {
      steps {
        withCredentials([usernamePassword(credentialsId: "${AWS_CREDS}",
                          usernameVariable: 'AWS_ACCESS_KEY_ID',
                          passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            set -eux
            aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
            aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
            aws configure set default.region ${AWS_REGION}

            TARGETS=$(aws elbv2 describe-target-health \
              --target-group-arn ${TARGET_GROUP_ARN} \
              --query "TargetHealthDescriptions[].Target.Id" --output text)

            for IID in $TARGETS; do
              echo ">> Deregister $IID"
              aws elbv2 deregister-targets --target-group-arn ${TARGET_GROUP_ARN} --targets Id=$IID
              aws elbv2 wait target-deregistered --target-group-arn ${TARGET_GROUP_ARN} --targets Id=$IID || true

              echo ">> Update on $IID via SSM"
              # Actualiza el tag en el unit file y reinicia
              aws ssm send-command \
                --document-name "AWS-RunShellScript" \
                --instance-ids "$IID" \
                --parameters commands="\
                  sed -i \"s|^Environment=IMAGE_URI=.*|Environment=IMAGE_URI=${IMAGE_URI}|\" /etc/systemd/system/${APP_NAME}.service && \
                  systemctl daemon-reload && \
                  systemctl restart ${APP_NAME}.service
                " \
                --comment "Deploy ${IMAGE_URI}" \
                --output text >/dev/null

              echo ">> Re-register $IID"
              aws elbv2 register-targets --target-group-arn ${TARGET_GROUP_ARN} --targets Id=$IID
              aws elbv2 wait target-in-service --target-group-arn ${TARGET_GROUP_ARN} --targets Id=$IID
            done
          '''
        }
      }
    }
  }
}
