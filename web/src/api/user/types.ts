import type { AuthUser } from '#ui/api/auth';
import type { PageResult } from '#ui/api/envelope';

export interface UserListItem extends AuthUser {}

export interface UserListResult extends PageResult<UserListItem> {}

export interface CreateUserRequest {
  name: string;
  email: string;
  password: string;
  admin?: boolean;
  tenant_id?: number;
}

export interface UpdateUserRequest {
  name?: string;
  email?: string;
  verified?: boolean;
  admin?: boolean;
}
