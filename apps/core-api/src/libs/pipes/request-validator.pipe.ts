import { BadRequestException, ValidationPipe, type ValidationError } from '@nestjs/common';

const errorMessages: Record<string, (property: string) => string> = {
  isNotEmpty: (prop) => `${prop}은(는) 비어있을 수 없습니다.`,
  isString: (prop) => `${prop}은(는) 문자열이어야 합니다.`,
  isEmail: (prop) => `${prop}은(는) 유효한 이메일 형식이 아닙니다.`,
  isBoolean: (prop) => `${prop}은(는) boolean 타입이어야 합니다.`,
  isNumber: (prop) => `${prop}은(는) 숫자 타입이어야 합니다.`,
  isEnum: (prop) => `${prop}은(는) 유효한 타입이 아닙니다.`,
  maxLength: (prop) => `${prop}의 길이가 너무 깁니다.`,
  // NOTE: 필요할 때마다 여기에 추가만 하면 앱 전체에 적용됩니다.
};

const getFirstErrorMessage = (error: ValidationError): string => {
  if (error.constraints) {
    const constraintKey = Object.keys(error.constraints)[0];

    if (errorMessages[constraintKey]) {
      return errorMessages[constraintKey](error.property);
    }
    return Object.values(error.constraints)[0];
  }

  if (error.children && error.children.length > 0) {
    return getFirstErrorMessage(error.children[0]);
  }

  return '잘못된 요청입니다.';
};

export const requesterValidatorPipe = new ValidationPipe({
  whitelist: true,
  transform: true,
  exceptionFactory: (errors) => {
    const firstErrorMessage = getFirstErrorMessage(errors[0]);
    throw new BadRequestException(firstErrorMessage, { description: firstErrorMessage });
  },
});
