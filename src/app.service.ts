import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): string {
    return `Hola bros NODE_ENV=${process.env.NODE_ENV ?? 'undefined'} como tan`;
  }
}
