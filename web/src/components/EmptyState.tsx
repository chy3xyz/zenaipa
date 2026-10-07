import { Show, type JSX } from 'solid-js';

interface EmptyStateProps {
  icon?: string;
  title: string;
  description?: string;
  action?: JSX.Element;
}

/** 列表/面板空态：图标 + 标题 + 说明 + 动作插槽。 */
export function EmptyState(props: EmptyStateProps) {
  return (
    <div class="flex flex-col items-center justify-center gap-2 py-10 text-center">
      <Show when={props.icon}>
        <div class="text-3xl">{props.icon}</div>
      </Show>
      <div class="text-sm font-medium text-base-content/70">{props.title}</div>
      <Show when={props.description}>
        <div class="max-w-sm text-xs text-base-content/50">{props.description}</div>
      </Show>
      <Show when={props.action}>
        <div class="mt-2">{props.action}</div>
      </Show>
    </div>
  );
}
