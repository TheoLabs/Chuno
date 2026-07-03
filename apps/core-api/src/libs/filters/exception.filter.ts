import {
  type ArgumentsHost,
  Catch,
  HttpException,
  HttpStatus,
  Logger,
  ExceptionFilter as NestExceptionFilter,
} from '@nestjs/common';
import type { Request, Response } from 'express';
import { Context, ContextKey } from '@libs/context';
import { ConfigsService } from '@configs';
import { getLogContext } from '@libs/logger';

// description을 넘기지 않은 예외(ValidationPipe·기본 HttpException)의 getResponse().error 에는
// Nest가 채우는 표준 문구가 들어온다. 이건 클라용 description이 아니므로 걸러낸다.
const DEFAULT_HTTP_PHRASES = new Set([
  'Bad Request',
  'Unauthorized',
  'Forbidden',
  'Not Found',
  'Method Not Allowed',
  'Not Acceptable',
  'Request Timeout',
  'Conflict',
  'Gone',
  'Unprocessable Entity',
  'Too Many Requests',
  'Internal Server Error',
]);

@Catch()
export class ExceptionFilter implements NestExceptionFilter {
  private readonly logger = new Logger();

  constructor(
    private readonly context: Context,
    private readonly configsService: ConfigsService
  ) {}

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<Request>();
    const response = ctx.getResponse<Response>();

    const status = exception instanceof HttpException ? exception.getStatus() : HttpStatus.INTERNAL_SERVER_ERROR;

    const exceptionResponse = exception instanceof HttpException ? exception.getResponse() : 'Internal Server Error';

    const txId = this.context.get<string>(ContextKey.TXID);
    const stack = exception instanceof Error ? exception.stack : '';

    const logPayload = {
      message: `[${request.method}] ${request.url} - ${txId}${'\n' + stack}`,
      txId,
      stack,
      // 서버용 = 예외 1번째 인자(getResponse().message)
      error: this.resolveServerMessage(exceptionResponse),
      ...getLogContext(request),
    };

    if (status >= Number(HttpStatus.INTERNAL_SERVER_ERROR)) {
      this.logger.error(logPayload);
    } else {
      this.logger.warn(logPayload);
    }

    response.status(status).json({
      data: {
        // 클라용 = description(getResponse().error)
        message: this.resolveClientMessage(status, exceptionResponse),
      },
    });
  }

  // 서버 로그용 메시지: 예외 1번째 인자(message)를 노출.
  private resolveServerMessage(res: string | object): unknown {
    if (typeof res === 'string') return res;
    return (res as { message?: unknown }).message ?? res;
  }

  // 클라 응답용 메시지: description(getResponse().error)을 우선 노출.
  private resolveClientMessage(status: number, res: string | object): unknown {
    if (status >= Number(HttpStatus.INTERNAL_SERVER_ERROR)) {
      return '서버에 예기치 않은 오류가 발생했습니다.';
    }
    if (typeof res === 'string') return res;

    const body = res as { message?: unknown; error?: unknown };

    // description은 getResponse().error 에 담긴다. Nest 표준 문구는 description이 아니므로 제외.
    const description =
      typeof body.error === 'string' && !DEFAULT_HTTP_PHRASES.has(body.error) ? body.error : undefined;
    if (description) return description;

    // description이 없을 때 폴백: ValidationPipe 메시지(배열)는 그대로, 그 외엔 message.
    if (Array.isArray(body.message)) return body.message;
    return body.message ?? '요청을 처리할 수 없습니다.';
  }
}
