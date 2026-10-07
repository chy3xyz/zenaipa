import { For, Show, type JSX } from 'solid-js';

import { EmptyState } from '#ui/components/EmptyState';
import { Pagination } from '#ui/components/Pagination';

export interface Column<T> {
  key: string;
  title: string;
  render: (row: T) => JSX.Element;
  class?: string;
  headerClass?: string;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T) => string | number;
  total: number;
  page: number;
  totalPages: number;
  loading: boolean;
  error: string | null;
  emptyText?: string;
  onPageChange: (page: number) => void;
  /** 传入则显示页大小选择器（配合 usePaged().changePageSize）。 */
  pageSize?: number;
  onPageSizeChange?: (n: number) => void;
  actions?: (row: T) => JSX.Element;
  actionsTitle?: string;
}

/**
 * Data-driven table: columns config + rows + pagination state from `usePaged`,
 * with shared loading/empty/error rendering, a full pager (页码/页大小/跳页)
 * and a loading overlay so later-page fetches are visible too.
 */
export default function DataTable<T>(props: DataTableProps<T>) {
  const columnCount = () => props.columns.length + (props.actions ? 1 : 0);

  return (
    <div class="space-y-4">
      <Show when={props.error}>
        <div role="alert" class="alert alert-error py-2 text-sm">
          {props.error}
        </div>
      </Show>

      <div class="relative overflow-x-auto rounded-lg border border-base-300">
        <table class="table" classList={{ 'opacity-50': props.loading }}>
          <thead>
            <tr>
              <For each={props.columns}>{(col) => <th class={col.headerClass}>{col.title}</th>}</For>
              <Show when={props.actions}>
                <th class="sticky right-0 bg-base-100 text-right">{props.actionsTitle ?? '操作'}</th>
              </Show>
            </tr>
          </thead>
          <tbody>
            <Show when={props.loading && props.rows.length === 0}>
              <For each={[0, 1, 2]}>
                {() => (
                  <tr>
                    <For each={props.columns}>
                      {() => (
                        <td class="py-2">
                          <div class="skeleton h-4 w-full" />
                        </td>
                      )}
                    </For>
                    <Show when={props.actions}>
                      <td>
                        <div class="skeleton ml-auto h-6 w-16" />
                      </td>
                    </Show>
                  </tr>
                )}
              </For>
            </Show>
            <Show when={props.rows.length === 0 && !props.loading}>
              <tr>
                <td colspan={columnCount()} class="p-0">
                  <EmptyState title={props.emptyText ?? '暂无数据'} />
                </td>
              </tr>
            </Show>
            <For each={props.rows}>
              {(row) => (
                <tr class="hover:bg-base-200/50">
                  <For each={props.columns}>{(col) => <td class={col.class}>{col.render(row)}</td>}</For>
                  <Show when={props.actions}>
                    <td class="sticky right-0 bg-base-100 text-right">
                      <div class="flex justify-end gap-1">{props.actions!(row)}</div>
                    </td>
                  </Show>
                </tr>
              )}
            </For>
          </tbody>
        </table>
        <Show when={props.loading && props.rows.length > 0}>
          <div class="pointer-events-none absolute inset-0 flex items-center justify-center bg-base-100/40">
            <span class="loading loading-spinner loading-md text-primary" />
          </div>
        </Show>
      </div>

      <Pagination
        page={props.page}
        pageSize={props.pageSize ?? 20}
        total={props.total}
        totalPages={props.totalPages}
        loading={props.loading}
        onPageChange={props.onPageChange}
        onPageSizeChange={props.onPageSizeChange}
      />
    </div>
  );
}
