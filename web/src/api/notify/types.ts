import type { PageResult } from '#ui/api/envelope';

export interface NotificationItem {
  id: number;
  title: string;
  body: string;
  read: boolean;
  kind: 'info' | 'success' | 'warning' | 'error';
  created_at: number;
}

export interface NotificationListResult extends PageResult<NotificationItem> {}
