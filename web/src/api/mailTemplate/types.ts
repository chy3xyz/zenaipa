import type { PageResult } from '#ui/api/envelope';

export interface MailTemplateItem {
  code: string;
  subject: string;
  body: string;
  updated_at: number;
}

export interface MailTemplateListResult extends PageResult<MailTemplateItem> {}
