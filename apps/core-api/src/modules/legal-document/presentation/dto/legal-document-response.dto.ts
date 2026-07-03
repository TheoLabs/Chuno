import { ResponseDto } from '@libs/utils';
import { LegalDocumentStatus, LegalDocumentType } from '@modules/legal-document/domain/legal-document.entity';
import { Exclude, Expose } from 'class-transformer';

@Exclude()
abstract class BaseLegalDocumentResponseDto extends ResponseDto {
  @Expose()
  id: number;

  @Expose()
  type: LegalDocumentType;

  @Expose()
  version: string;

  @Expose()
  title: string;

  @Expose()
  isRequired: boolean;

  @Expose()
  status: LegalDocumentStatus;
}

@Exclude()
export class GeneralLegalDocumentListResponseDto extends BaseLegalDocumentResponseDto {}

@Exclude()
export class GeneralLegalDocumentDetailResponseDto extends BaseLegalDocumentResponseDto {
  @Expose()
  content: string;

  @Expose()
  expectedActivateOn: string;
}
