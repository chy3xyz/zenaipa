import type { PageResult } from '#ui/api/envelope';

export interface FileItem {
  id: number;
  name: string;
  mime: string;
  size_bytes: number;
  uploader_id: number;
  created_at: number;
}

export interface FileListResult extends PageResult<FileItem> {}
