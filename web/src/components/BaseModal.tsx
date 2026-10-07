import { Show, type JSX } from 'solid-js';

export type ModalSize = 'sm' | 'md' | 'lg' | 'xl';

const sizeClass: Record<ModalSize, string> = {
  sm: 'max-w-sm',
  md: 'max-w-lg',
  lg: 'max-w-2xl',
  xl: 'max-w-4xl',
};

interface BaseModalProps {
  open: boolean;
  title: string;
  size?: ModalSize;
  onClose: () => void;
  children?: JSX.Element;
}

/** 弹窗外壳（chrome only）：标题栏 + 可滚动正文 + 遮罩点击关闭。布局交给调用方。 */
export function BaseModal(props: BaseModalProps) {
  return (
    <Show when={props.open}>
      <div
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4"
        role="dialog"
        aria-modal="true"
        onClick={props.onClose}
      >
        <div
          class={`w-full ${sizeClass[props.size ?? 'md']} rounded-box border border-base-300 bg-base-100 shadow-xl`}
          onClick={(e) => e.stopPropagation()}
        >
          <div class="flex items-center justify-between border-b border-base-300 px-4 py-3">
            <h3 class="text-base font-semibold">{props.title}</h3>
            <button type="button" class="btn btn-ghost btn-xs" aria-label="关闭" onClick={props.onClose}>
              ✕
            </button>
          </div>
          <div class="max-h-[85vh] overflow-y-auto px-4 py-4">{props.children}</div>
        </div>
      </div>
    </Show>
  );
}
