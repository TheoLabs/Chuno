import { CallHandler, ExecutionContext, Injectable, Logger, NestInterceptor } from '@nestjs/common';
import { type Observable, tap } from 'rxjs';
import type { Request } from 'express';
import { Context, ContextKey } from '@libs/context';
import { getLogContext } from '@libs/logger';

@Injectable()
export class RequestLoggerInterceptor implements NestInterceptor {
  private readonly logger = new Logger();

  private readonly ignoredPaths = ['/health', '/metrics', '/favicon.ico'];

  constructor(private readonly context: Context) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const request = context.switchToHttp().getRequest<Request>();

    const startTime = Date.now();

    // NOTE: 로그 도배 방지를 위해 health, metrics, favicon.ico는 로깅하지 않음
    if (this.ignoredPaths.some((path) => request.url.startsWith(path))) {
      return next.handle();
    }

    return next.handle().pipe(
      tap(() => {
        const payload = {
          message: `[${request.method}]: ${request.url} (${Date.now() - startTime}ms) - ${this.context.get<string>(ContextKey.TXID)}`,
          txId: this.context.get<string>(ContextKey.TXID),
          ...getLogContext(request),
        };
        this.logger.log(payload);
      })
    );
  }
}
