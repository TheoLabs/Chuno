import { ToArray } from '@libs/decorators';
import { PaginationDto } from '@libs/utils';
import { IsEnum, IsOptional } from 'class-validator';
import { LegalDocumentType } from '../../domain/legal-document.entity';

abstract class BaseLegalDocumentQueryDto extends PaginationDto {
  @ToArray()
  @IsEnum(LegalDocumentType, { each: true })
  @IsOptional()
  types?: LegalDocumentType[];
}

export class GeneralLegalDocumentQueryDto extends BaseLegalDocumentQueryDto {}
