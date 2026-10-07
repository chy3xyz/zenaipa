import { Show, type JSX } from 'solid-js';

interface StatCardProps {
  label: string;
  value: JSX.Element;
  hint?: string;
}

/** 仪表盘/统计页的数值卡片（从 Dashboard/Tasks 的重复实现上提）。 */
export function StatCard(props: StatCardProps) {
  return (
    <div class="rounded-box border border-base-300 bg-base-100 p-4">
      <div class="text-xs text-base-content/60">{props.label}</div>
      <div class="mt-1 text-2xl font-semibold">{props.value}</div>
      <Show when={props.hint}>
        <div class="mt-1 text-xs text-base-content/50">{props.hint}</div>
      </Show>
    </div>
  );
}
