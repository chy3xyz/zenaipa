import { createSignal, For, Show } from 'solid-js';

export const DEFAULT_PAGE_SIZES = [10, 20, 50, 100];

interface PaginationProps {
  page: number;
  pageSize: number;
  total: number;
  totalPages: number;
  loading?: boolean;
  onPageChange: (page: number) => void;
  onPageSizeChange?: (n: number) => void;
}

/** 页码窗口：以当前页为中心的 5 个连续页码，夹在 [1, totalPages] 内。 */
function pageWindow(page: number, totalPages: number): number[] {
  const size = 5;
  let start = Math.max(1, page - Math.floor(size / 2));
  const end = Math.min(totalPages, start + size - 1);
  start = Math.max(1, end - size + 1);
  const out: number[] = [];
  for (let p = start; p <= end; p++) out.push(p);
  return out;
}

/** 完整分页器：共 N 条 + 页大小选择 + 首页/上下页/页码/末页 + 跳页。加载中全部禁用。 */
export function Pagination(props: PaginationProps) {
  const [jump, setJump] = createSignal('');

  const go = (p: number) => {
    if (props.loading) return;
    const target = Math.min(Math.max(1, p), props.totalPages);
    if (target !== props.page) props.onPageChange(target);
  };

  const submitJump = (e: Event) => {
    e.preventDefault();
    const n = Number.parseInt(jump(), 10);
    if (Number.isFinite(n)) go(n);
    setJump('');
  };

  return (
    <div class="flex flex-wrap items-center justify-between gap-2">
      <span class="text-sm text-base-content/60">共 {props.total} 条</span>
      <div class="flex flex-wrap items-center gap-2">
        <Show when={props.onPageSizeChange}>
          <select
            class="select select-bordered select-sm"
            disabled={props.loading}
            value={props.pageSize}
            onChange={(e) => props.onPageSizeChange?.(Number(e.currentTarget.value))}
            aria-label="每页条数"
          >
            <For each={DEFAULT_PAGE_SIZES}>{(n) => <option value={n}>{n} 条/页</option>}</For>
          </select>
        </Show>
        <div class="join">
          <button type="button" class="btn btn-sm join-item" disabled={props.loading || props.page <= 1} onClick={() => go(1)}>
            首页
          </button>
          <button
            type="button"
            class="btn btn-sm join-item"
            disabled={props.loading || props.page <= 1}
            onClick={() => go(props.page - 1)}
          >
            上一页
          </button>
          <For each={pageWindow(props.page, props.totalPages)}>
            {(p) => (
              <button
                type="button"
                class="btn btn-sm join-item"
                classList={{ 'btn-primary': p === props.page }}
                disabled={props.loading}
                onClick={() => go(p)}
              >
                {p}
              </button>
            )}
          </For>
          <button
            type="button"
            class="btn btn-sm join-item"
            disabled={props.loading || props.page >= props.totalPages}
            onClick={() => go(props.page + 1)}
          >
            下一页
          </button>
          <button
            type="button"
            class="btn btn-sm join-item"
            disabled={props.loading || props.page >= props.totalPages}
            onClick={() => go(props.totalPages)}
          >
            末页
          </button>
        </div>
        <form class="flex items-center gap-1" onSubmit={submitJump}>
          <input
            type="number"
            min={1}
            max={props.totalPages}
            class="input input-bordered input-sm w-16"
            placeholder="页码"
            disabled={props.loading}
            value={jump()}
            onInput={(e) => setJump(e.currentTarget.value)}
            aria-label="跳至页码"
          />
          <button type="submit" class="btn btn-sm" disabled={props.loading}>
            跳转
          </button>
        </form>
      </div>
    </div>
  );
}
