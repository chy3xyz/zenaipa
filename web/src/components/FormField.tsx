import { Show, type JSX } from 'solid-js';

interface FormFieldProps {
  label: string;
  required?: boolean;
  /** 控件下方的弱化提示。 */
  hint?: string;
  /** 右侧附加内容（如"选填"说明）。 */
  labelExtra?: JSX.Element;
  children?: JSX.Element;
}

/** 统一字段包装：小标签 + 必填红星 + hint。所有弹窗/表单字段都应使用。 */
export function FormField(props: FormFieldProps) {
  return (
    <div>
      <div class="flex items-center justify-between">
        <span class="text-sm text-base-content/80">
          {props.label}
          <Show when={props.required}>
            <span class="ml-0.5 text-error">*</span>
          </Show>
        </span>
        <Show when={props.labelExtra}>{props.labelExtra}</Show>
      </div>
      <div class="mt-1">{props.children}</div>
      <Show when={props.hint}>
        <div class="mt-1 text-xs text-base-content/50">{props.hint}</div>
      </Show>
    </div>
  );
}
