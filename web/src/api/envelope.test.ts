import { describe, expect, it } from 'vitest';

import { ApiError, unwrapEnvelope, type PageResult } from './envelope';

describe('unwrapEnvelope', () => {
  it('returns data on code=0', () => {
    expect(unwrapEnvelope({ code: 0, msg: 'ok', data: { id: 7 } })).toEqual({ id: 7 });
    expect(unwrapEnvelope({ code: 0, msg: 'ok', data: null })).toBeNull();
  });

  it('throws ApiError carrying code and server msg on non-zero code', () => {
    expect.assertions(3);
    try {
      unwrapEnvelope<string>({ code: 40001, msg: '验证码已过期', data: '' });
    } catch (err) {
      expect(err).toBeInstanceOf(ApiError);
      expect((err as ApiError).code).toBe(40001);
      expect((err as ApiError).message).toBe('验证码已过期');
    }
  });

  it('falls back to a generic message when msg is empty', () => {
    expect.assertions(2);
    try {
      unwrapEnvelope({ code: 500, msg: '', data: null });
    } catch (err) {
      expect(err).toBeInstanceOf(ApiError);
      expect((err as ApiError).message).toBe('Request failed');
    }
  });
});

describe('PageResult', () => {
  it('models the paged payload shape (compile-level)', () => {
    const page: PageResult<{ id: number }> = { list: [{ id: 1 }], total: 1, page: 1 };
    expect(page.list).toHaveLength(1);
    expect(page.list[0]?.id).toBe(1);
    expect(page.total).toBe(1);
    expect(page.page).toBe(1);
    expect(page.pageSize).toBeUndefined();
  });

  it('accepts an optional pageSize', () => {
    const page: PageResult<number> = { list: [1, 2], total: 2, page: 1, pageSize: 20 };
    expect(page.pageSize).toBe(20);
  });

  it('list-result interfaces stay assignable to PageResult', () => {
    interface UserListResult extends PageResult<{ id: number }> {}
    const r: UserListResult = { list: [{ id: 3 }], total: 1, page: 2, pageSize: 10 };
    expect(r.list[0]?.id).toBe(3);
  });
});
