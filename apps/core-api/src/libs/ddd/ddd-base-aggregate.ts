import { stripUndefined } from 'src/libs/utils';
import { isEqual } from 'lodash';
import { ClassConstructor, plainToInstance } from 'class-transformer';
import { Column, CreateDateColumn, DeleteDateColumn, UpdateDateColumn } from 'typeorm';

/**
 * 영속 엔티티 공통 베이스 — 감사 컬럼(createdAt/updatedAt/deletedAt + by) + 공용 헬퍼.
 * **도메인 이벤트는 없다.** 애그리게이트 루트가 아닌 owned child 엔티티(예: Line/SoundEffect/CutEffect)가 상속한다.
 * 루트는 이벤트를 갖는 {@link DddAggregate}(이 클래스를 확장)를 상속한다.
 */
export abstract class DddBaseAggregate {
  @CreateDateColumn()
  readonly createdAt: Date;

  @Column({ select: false, nullable: true })
  private createdBy?: string;

  @UpdateDateColumn()
  readonly updatedAt: Date;

  @Column({ select: false, nullable: true })
  private updatedBy?: string;

  @DeleteDateColumn({ nullable: true })
  deletedAt: Date | null;

  setTraceId(traceId: string) {
    if (!this.createdAt) {
      this.createdBy = traceId;
    }
    this.updatedBy = traceId;
  }

  /**
   * @param changed 변경된 obj
   * @returns 현재 객체와 changed를 비교해 변경된 부분만 반환한다. 바뀐 게 없으면 undefined.
   */
  protected stripUnchanged(changed: { [key: string]: any }) {
    const compared = Object.keys(changed).reduce((acc: { [key: string]: any }, prop) => {
      const originValue = this[prop as keyof typeof this];
      const changedValue = changed[prop];
      acc[prop] = !isEqual(originValue, changedValue) ? changedValue : undefined;
      return acc;
    }, {});

    return stripUndefined(compared);
  }

  toInstance<T>(dto: ClassConstructor<T>, args?: Record<string, unknown>) {
    return plainToInstance(dto, { ...this, ...args });
  }
}
