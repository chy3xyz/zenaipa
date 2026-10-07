import { createSignal } from 'solid-js';
import { renderHook, waitFor } from '@solidjs/testing-library';
import { describe, expect, it, vi } from 'vitest';

import { usePaged, type PagedPayload } from './usePaged';

type Payload = PagedPayload<number>;

describe('usePaged', () => {
  it('auto-loads page 1 on mount', async () => {
    const loader = vi.fn(async (page: number, pageSize: number): Promise<Payload> => ({
      list: [1, 2],
      total: 2,
      page,
    }));

    const { result } = renderHook(() => usePaged<number>(loader, { pageSize: 20 }));

    expect(result.loading()).toBe(true);
    await waitFor(() => expect(loader).toHaveBeenCalledTimes(1));
    expect(loader).toHaveBeenLastCalledWith(1, 20);
    expect(result.items()).toEqual([1, 2]);
    expect(result.total()).toBe(2);
    expect(result.page()).toBe(1);
    expect(result.loading()).toBe(false);
    expect(result.error()).toBeNull();
  });

  it('discards a stale response that resolves after a newer request', async () => {
    let resolvers: ((v: Payload) => void)[] = [];
    const loader = vi.fn(
      (page: number, _pageSize: number) =>
        new Promise<Payload>((resolve) => {
          resolvers.push(resolve);
        }),
    );

    const { result } = renderHook(() => usePaged<number>(loader));
    await waitFor(() => expect(loader).toHaveBeenCalledTimes(1));

    const stale = result.reload(2);
    await waitFor(() => expect(loader).toHaveBeenCalledTimes(2));

    // 第 2 页先返回并被采纳
    resolvers[1]({ list: [2], total: 1, page: 2 });
    await waitFor(() => expect(result.items()).toEqual([2]));
    expect(result.page()).toBe(2);

    // 第 1 页后返回:乱序,必须被丢弃
    resolvers[0]({ list: [1], total: 1, page: 1 });
    await stale;

    expect(result.items()).toEqual([2]);
    expect(result.page()).toBe(2);
    expect(result.loading()).toBe(false);

    resolvers = [];
  });

  it('changePageSize reloads page 1 with the new size', async () => {
    const loader = vi.fn(async (page: number, _pageSize: number): Promise<Payload> => ({
      list: [],
      total: 100,
      page,
    }));

    const { result } = renderHook(() => usePaged<number>(loader, { pageSize: 20 }));
    await waitFor(() => expect(loader).toHaveBeenLastCalledWith(1, 20));

    await result.changePageSize(50);

    expect(loader).toHaveBeenCalledTimes(2);
    expect(loader).toHaveBeenLastCalledWith(1, 50);
    expect(result.pageSize()).toBe(50);
    expect(result.page()).toBe(1);
    expect(result.total()).toBe(100);
  });

  it('watch accessor triggers a page-1 reload when its value changes (first run skipped)', async () => {
    const loader = vi.fn(async (page: number, _pageSize: number): Promise<Payload> => ({
      list: [],
      total: 0,
      page,
    }));
    const [keyword, setKeyword] = createSignal('');

    const { result } = renderHook(() => usePaged<number>(loader, { watch: () => keyword() }));
    await waitFor(() => expect(loader).toHaveBeenCalledTimes(1));
    expect(loader).toHaveBeenLastCalledWith(1, 20);

    setKeyword('foo');
    await waitFor(() => expect(loader).toHaveBeenCalledTimes(2));
    expect(loader).toHaveBeenLastCalledWith(1, 20);
    expect(result.page()).toBe(1);
  });
});
