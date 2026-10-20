import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PgBoss } from 'pg-boss';

/**
 * pg-boss wrapper — delayed job-уудыг Postgres дотор хадгална (Redis хэрэггүй).
 * Session pooler (DIRECT_URL) ашиглана: pgBouncer transaction mode-той
 * зохицохгүй тул transaction pooler URL өгч болохгүй.
 */
@Injectable()
export class JobsService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(JobsService.name);
  private boss: PgBoss;
  private started = false;

  async onModuleInit() {
    const url = process.env.PGBOSS_URL ?? process.env.DIRECT_URL;
    if (!url) {
      this.logger.warn('DIRECT_URL тохируулаагүй — job scheduler идэвхгүй');
      return;
    }
    this.boss = new PgBoss({ connectionString: url, schema: 'pgboss' });
    this.boss.on('error', (err: Error) => this.logger.error(`pg-boss: ${err.message}`));
    await this.boss.start();
    this.started = true;
    this.logger.log('pg-boss started');
  }

  async onModuleDestroy() {
    if (this.started) await this.boss.stop({ graceful: true });
  }

  /** Заасан хугацаанд ажиллах job илгээнэ. */
  async sendAt(queue: string, data: object, runAt: Date): Promise<void> {
    if (!this.started) return;
    await this.boss.createQueue(queue);
    await this.boss.send(queue, data, { startAfter: runAt, retryLimit: 5, retryDelay: 10 });
  }

  /** Queue-д worker бүртгэнэ. */
  async work<T extends object>(queue: string, handler: (data: T) => Promise<void>): Promise<void> {
    if (!this.started) return;
    await this.boss.createQueue(queue);
    await this.boss.work<T>(queue, async (jobs: { data: T }[]) => {
      for (const job of jobs) {
        await handler(job.data);
      }
    });
  }
}
