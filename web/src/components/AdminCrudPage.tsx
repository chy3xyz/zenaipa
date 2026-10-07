import { Show, type JSX } from 'solid-js';

interface AdminCrudPageProps {
  title: string;
  description?: string;
  /** 列表总数（如来自 usePaged().total()），显示"共 N 条"。 */
  total?: number;
  /** 动作行左侧插槽（自定义按钮等）。 */
  extra?: JSX.Element;
  onRefresh?: () => void;
  onCreate?: () => void;
  createLabel?: string;
  /** 筛选卡内容（SearchBar / 自定义表单）。 */
  filter?: JSX.Element;
  children?: JSX.Element;
}

/** 标准管理页骨架：页头(标题/描述/总数) + 动作行(刷新/新增) + 可选筛选卡 + 内容卡。 */
export function AdminCrudPage(props: AdminCrudPageProps) {
  return (
    <div class="space-y-4">
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div>
          <h2 class="text-xl font-semibold">{props.title}</h2>
          <Show when={props.description}>
            <p class="mt-0.5 text-sm text-base-content/60">{props.description}</p>
          </Show>
          <Show when={props.total != null}>
            <p class="mt-0.5 text-xs text-base-content/50">共 {props.total} 条</p>
          </Show>
        </div>
        <div class="flex items-center gap-2">
          {props.extra}
          <Show when={props.onRefresh}>
            <button type="button" class="btn btn-outline btn-sm" disabled={false} onClick={() => props.onRefresh?.()}>
              刷新
            </button>
          </Show>
          <Show when={props.onCreate}>
            <button type="button" class="btn btn-primary btn-sm" onClick={() => props.onCreate?.()}>
              {props.createLabel ?? '新增'}
            </button>
          </Show>
        </div>
      </div>

      <Show when={props.filter}>
        <div class="rounded-box border border-base-300 bg-base-100 p-4">{props.filter}</div>
      </Show>

      <div class="rounded-box border border-base-300 bg-base-100 p-4">{props.children}</div>
    </div>
  );
}
