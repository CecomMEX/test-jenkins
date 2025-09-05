# syntax=docker/dockerfile:1.7

############################
# Etapa deps (con dev deps)
############################
FROM node:20-slim AS deps
WORKDIR /app
# IMPORTANTE: development aquí para incluir devDependencies
ENV NODE_ENV=development
ENV CI=true

COPY package*.json ./
# Cache de npm para acelerar builds
RUN --mount=type=cache,target=/root/.npm npm ci

############################
# Etapa build
############################
FROM deps AS builder
COPY . .
# Compila usando Nest CLI (dev dep) y luego quita dev deps
RUN npm run build
RUN npm prune --omit=dev

############################
# Etapa runtime (solo prod)
############################
FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV CI=true

# Copia solo lo necesario
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

# Corre como usuario no root
USER node

EXPOSE 3000

# (Opcional) Healthcheck si tienes /health
# HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD node -e "http=require('http');req=http.get({host:'127.0.0.1',port:3000,path:'/health'},r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1));"

CMD ["node", "dist/main.js"]
