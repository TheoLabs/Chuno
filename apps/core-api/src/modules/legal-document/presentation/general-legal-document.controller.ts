import { UserGuard } from '@libs/guards';
import { GeneralLegalDocumentService } from '@modules/legal-document/applications/general-legal-document.service';
import { GeneralLegalDocumentQueryDto } from '@modules/legal-document/presentation/dto';
import { Controller, Get, Param, ParseIntPipe, Query, UseGuards } from '@nestjs/common';

@Controller('legal-documents')
@UseGuards(UserGuard)
export class GeneralLegalDocumentController {
  constructor(private readonly generalLegalDocumentService: GeneralLegalDocumentService) {}

  @Get()
  async list(@Query() query: GeneralLegalDocumentQueryDto) {
    // 1. Destructure body, params, query
    const { types, ...options } = query;

    // 2. Get context
    // 3. Get result
    const data = await this.generalLegalDocumentService.list({ types }, options);

    // 4. Send response
    return { data };
  }

  @Get(':id')
  async retrieve(@Param('id', ParseIntPipe) id: number) {
    // 1. Destructure body, params, query
    // 2. Get context
    // 3. Get result
    const data = await this.generalLegalDocumentService.retrieve({ id });

    // 4. Send response
    return { data };
  }
}
