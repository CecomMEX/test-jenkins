import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    return `NODE_ENV=${process.env.NODE_ENV ?? 'undefined'} ${process.env.DYNAMO_USER ?? 'ha'} best test`;
  }
}
