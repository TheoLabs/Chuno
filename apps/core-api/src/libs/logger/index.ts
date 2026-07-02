import { type Request } from 'express';
import { WinstonModule } from 'nest-winston';
import * as winston from 'winston';

const { combine, timestamp, printf, colorize } = winston.format;

const yellow = '\x1b[33m';
const reset = '\x1b[0m';

const logFormat = printf(({ level, message, timestamp }: { level: string; message: string; timestamp: string }) => {
  return `${yellow}${timestamp}${reset} [${level}] ${message}`;
});

const isLocal = process.env.NODE_ENV !== 'production' && process.env.NODE_ENV !== 'development';

export const logger = WinstonModule.createLogger({
  defaultMeta: { service: `vogopang-${process.env.NODE_ENV || 'local'}` },
  transports: [
    new winston.transports.Console({
      level: isLocal ? 'debug' : 'info',
      format: isLocal
        ? combine(timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }), colorize({ all: true }), logFormat)
        : combine(timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }), winston.format.json()),
    }),
  ],
});

export function getLogContext(request: Request) {
  const { method, url, body } = request;
  const { authorization, ...safeHeaders } = request.headers;

  const isBodyEmpty = !body || Object.keys(body).length === 0;

  return {
    method,
    url,
    body: !isBodyEmpty ? JSON.stringify(body) : undefined,
    headers: safeHeaders,
  };
}
