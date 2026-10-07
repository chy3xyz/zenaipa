import type { PageResult } from '#ui/api/envelope';

export interface TenantItem {
  id: number;
  name: string;
  status: 'active' | 'disabled';
  created_at: number;
  updated_at: number;
}

export interface TenantListResult extends PageResult<TenantItem> {}

export interface CreateTenantRequest {
  name: string;
}

export interface UpdateTenantRequest {
  name?: string;
  status?: 'active' | 'disabled';
}
