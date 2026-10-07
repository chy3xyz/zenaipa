import type { PageResult } from '#ui/api/envelope';

export type TaskStatus = 'pending' | 'claimed' | 'done' | 'failed' | 'canceled';

export interface TaskItem {
  id: number;
  name: string;
  payload: string;
  status: TaskStatus;
  attempts: number;
  max_attempts: number;
  last_error: string;
  available_at: number;
  started_at: number;
  finished_at: number;
  created_at: number;
  updated_at: number;
}

export interface TaskListResult extends PageResult<TaskItem> {}

export interface TaskStats {
  pending: number;
  claimed: number;
  done: number;
  failed: number;
  canceled: number;
}
