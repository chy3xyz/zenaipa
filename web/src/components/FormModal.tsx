import { Show, type JSX } from 'solid-js';

import { BaseModal, type ModalSize } from '#ui/components/BaseModal';

interface FormModalProps {
  open: boolean;
  title: string;
  size?: ModalSize;
  description?: string;
  /** 顶部错误告警（每弹窗独立 error signal，勿与其它弹窗共用）。 */
  error?: string | null;
  submitting?: boolean;
  submitLabel?: string;
  submitDisabled?: boolean;
  onSubmit: (e: SubmitEvent) => void;
  onClose: () => void;
  children?: JSX.Element;
}

/** 标准表单弹窗：错误告警 + 提交态（spinner + 禁用）+ 取消/提交页脚。 */
export function FormModal(props: FormModalProps) {
  const handleSubmit = (e: SubmitEvent) => {
    e.preventDefault();
    if (props.submitting) return;
    props.onSubmit(e);
  };

  return (
    <BaseModal open={props.open} title={props.title} size={props.size} onClose={() => { if (!props.submitting) props.onClose(); }}>
      <form onSubmit={handleSubmit} class="space-y-3">
        <Show when={props.description}>
          <p class="text-sm text-base-content/60">{props.description}</p>
        </Show>
        <Show when={props.error}>
          <div role="alert" class="alert alert-error py-2 text-sm">
            {props.error}
          </div>
        </Show>
        {props.children}
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="btn btn-ghost btn-sm" disabled={props.submitting} onClick={props.onClose}>
            取消
          </button>
          <button type="submit" class="btn btn-primary btn-sm" disabled={props.submitting || props.submitDisabled}>
            <Show when={props.submitting}>
              <span class="loading loading-spinner loading-xs" />
            </Show>
            {props.submitting ? '提交中…' : (props.submitLabel ?? '保存')}
          </button>
        </div>
      </form>
    </BaseModal>
  );
}
