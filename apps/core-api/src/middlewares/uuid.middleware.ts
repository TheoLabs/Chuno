import { Injectable, NestMiddleware } from '@nestjs/common';
import { v7 as uuid } from 'uuid';
import type { Request, Response, NextFunction } from 'express';
import { ContextKey, Context } from '@libs/context';

@Injectable()
export class UUIDMiddleware implements NestMiddleware {
  constructor(private readonly context: Context) {}

  use(req: Request, _: Response, next: NextFunction) {
    const traceId = req.get('x-request-id') || uuid();
    this.context.set(ContextKey.TXID, traceId);
    next();
  }
}
