import { Injectable, NestMiddleware } from '@nestjs/common';
import type { Request, Response, NextFunction } from 'express';
import { asyncLocalStorage } from '@libs/context';

@Injectable()
export class ContextMiddleware implements NestMiddleware {
  use(_: Request, __: Response, next: NextFunction) {
    const store = new Map<string, any>();
    asyncLocalStorage.run(store, () => next());
  }
}
