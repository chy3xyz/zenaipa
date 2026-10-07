import { createEffect, createMemo, createSignal, on, onMount } from 'solid-js';

import { toApiError } from '#ui/api/client';

export interface PagedPayload<T> {
  list: T[];
  total: number;
  page: number;
}

export interface UsePagedOptions {
  /** 每页条数（默认 20；配合 changePageSize 变更）。 */
  pageSize?: number;
  /** 挂载时是否自动加载（默认 true）。 */
  immediate?: boolean;
  /** 访问器：其值变化即回第 1 页重查（搜索词、租户切换等），首次运行跳过。 */
  watch?: () => unknown;
}

/**
 * Server-side pagination state: one hook owns items/total/page/pageSize/
 * loading/error, auto-loads on mount, and guards with a monotonic request
 * sequence so rapid search/pagination cannot interleave out-of-order
 * responses.
 */
export function usePaged<T>(
  loader: (page: number, pageSize: number) => Promise<PagedPayload<T>>,
  opts: UsePagedOptions = {},
) {
  const [items, setItems] = createSignal<T[]>([]);
  const [total, setTotal] = createSignal(0);
  const [page, setPage] = createSignal(1);
  const [pageSize, setPageSize] = createSignal(opts.pageSize ?? 20);
  const [loading, setLoading] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);

  const totalPages = createMemo(() => Math.max(1, Math.ceil(total() / pageSize())));
  let requestSeq = 0;

  const reload = async (targetPage = page()) => {
    const seq = ++requestSeq;
    setLoading(true);
    setError(null);
    try {
      const result = await loader(targetPage, pageSize());
      if (seq !== requestSeq) return;
      setItems(result.list);
      setTotal(result.total);
      setPage(result.page);
    } catch (err) {
      if (seq !== requestSeq) return;
      setError(toApiError(err).message);
    } finally {
      if (seq === requestSeq) setLoading(false);
    }
  };

  /** 当前页重查（增删改后的就地刷新）。 */
  const refresh = () => reload(page());

  /** 变更每页条数并回第 1 页。 */
  const changePageSize = (n: number) => {
    setPageSize(n);
    return reload(1);
  };

  onMount(() => {
    if (opts.immediate !== false) void reload(1);
  });

  if (opts.watch) {
    // defer: 首次运行与 onMount 的自动加载是同一件事，跳过避免双请求。
    createEffect(
      on(opts.watch, () => {
        void reload(1);
      }, { defer: true }),
    );
  }

  return {
    items,
    total,
    page,
    pageSize,
    totalPages,
    loading,
    error,
    reload,
    refresh,
    changePageSize,
  };
}
