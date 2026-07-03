import { DddRepository } from '@libs/ddd';
import { CalendarDate } from '@libs/types';
import { checkInValue, checkRangeValue, convertOptions, stripUndefined, TypeormRelationOptions } from '@libs/utils';
import {
  LegalDocument,
  LegalDocumentStatus,
  LegalDocumentType,
} from '@modules/legal-document/domain/legal-document.entity';
import { Injectable } from '@nestjs/common';

@Injectable()
export class LegalDocumentRepository extends DddRepository<LegalDocument> {
  entityClass = LegalDocument;

  async find(
    conditions: {
      id?: number;
      version?: string;
      types?: LegalDocumentType[];
      statuses?: LegalDocumentStatus[];
      expectedActivateOn?: CalendarDate;
      minExpectedActivateOn?: CalendarDate;
      maxExpectedActivateOn?: CalendarDate;
    },
    options?: TypeormRelationOptions<LegalDocument>
  ) {
    return this.entityManager.find(this.entityClass, {
      where: stripUndefined({
        id: conditions.id,
        version: conditions.version,
        type: checkInValue(conditions.types),
        status: checkInValue(conditions.statuses),
        expectedActivateOn:
          conditions.expectedActivateOn ??
          checkRangeValue(conditions.minExpectedActivateOn, conditions.maxExpectedActivateOn),
      }),
      ...convertOptions(options),
    });
  }

  async count(conditions: {
    id?: number;
    version?: string;
    types?: LegalDocumentType[];
    statuses?: LegalDocumentStatus[];
    expectedActivateOn?: CalendarDate;
    minExpectedActivateOn?: CalendarDate;
    maxExpectedActivateOn?: CalendarDate;
  }) {
    return this.entityManager.count(this.entityClass, {
      where: stripUndefined({
        id: conditions.id,
        version: conditions.version,
        type: checkInValue(conditions.types),
        status: checkInValue(conditions.statuses),
        expectedActivateOn:
          conditions.expectedActivateOn ??
          checkRangeValue(conditions.minExpectedActivateOn, conditions.maxExpectedActivateOn),
      }),
    });
  }
}
