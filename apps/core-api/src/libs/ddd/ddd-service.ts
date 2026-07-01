import { Context } from 'src/libs/context';
import { Inject } from '@nestjs/common';
import { InjectEntityManager } from '@nestjs/typeorm';
import { EntityManager } from 'typeorm';

export abstract class DddService {
  @InjectEntityManager()
  private readonly entityManager!: EntityManager;

  @Inject()
  private readonly context!: Context;
}
