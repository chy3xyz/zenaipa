import { createContext, createSignal, useContext, For, Show, type JSX } from 'solid-js';

import { toApiError } from '#ui/api/client';

type ToastType = 'info' | 'success' | 'error';

interface ToastItem {
  id: number;
  msg: string;
  type: ToastType;
}

export interface ConfirmOptions {
  title: string;
  message?: string;
  confirmText?: string;
  cancelText?: string;
  /** 危险动作（删除等）：确认按钮变红。 */
  danger?: boolean;
}

export interface RunActionOptions {
  /** 传入则先弹确认框，用户取消则整个动作不执行。 */
  confirm?: ConfirmOptions;
  action: () => Promise<unknown>;
  /** 成功后的 toast 文案。 */
  success?: string;
  onDone?: () => void;
}

export interface FeedbackApi {
  show: (msg: string, type?: ToastType) => void;
  /** 样式化确认框（替代 window.confirm），resolve 为用户选择。 */
  confirm: (opts: ConfirmOptions) => Promise<boolean>;
  /** 动作标准流程：确认 → 执行 → 成功 toast / 失败 toast(服务端 msg) → onDone。 */
  runAction: (opts: RunActionOptions) => Promise<void>;
}

const FeedbackCtx = createContext<FeedbackApi | undefined>(undefined);

/** 全局反馈容器（toast + 确认框）。挂在应用根部；页面用 useFeedback() 取实例。 */
export function FeedbackProvider(props: { children?: JSX.Element }) {
  const [toasts, setToasts] = createSignal<ToastItem[]>([]);
  const [pending, setPending] = createSignal<(ConfirmOptions & { resolve: (ok: boolean) => void }) | null>(null);

  const show = (msg: string, type: ToastType = 'info') => {
    const id = Date.now() + Math.floor(Math.random() * 1000);
    setToasts((t) => [...t, { id, msg, type }]);
    window.setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3500);
  };

  const confirm = (opts: ConfirmOptions) =>
    new Promise<boolean>((resolve) => {
      setPending({ ...opts, resolve });
    });

  const settle = (ok: boolean) => {
    pending()?.resolve(ok);
    setPending(null);
  };

  const runAction = async (opts: RunActionOptions) => {
    if (opts.confirm && !(await confirm(opts.confirm))) return;
    try {
      await opts.action();
      if (opts.success) show(opts.success, 'success');
      opts.onDone?.();
    } catch (err) {
      show(toApiError(err).message, 'error');
    }
  };

  const icon = (t: ToastType) => (t === 'error' ? '✕' : t === 'success' ? '✓' : 'ℹ');

  return (
    <FeedbackCtx.Provider value={{ show, confirm, runAction }}>
      {props.children}

      <div class="toast toast-end toast-top z-[100] space-y-2">
        <For each={toasts()}>
          {(t) => (
            <div
              role="alert"
              class={`alert py-2 text-sm shadow-lg ${
                t.type === 'error' ? 'alert-error' : t.type === 'success' ? 'alert-success' : 'alert-info'
              }`}
            >
              <span>
                {icon(t.type)} {t.msg}
              </span>
            </div>
          )}
        </For>
      </div>

      <Show when={pending()}>
        {(p) => (
          <div class="fixed inset-0 z-[110] flex items-center justify-center bg-black/40 p-4" role="dialog" aria-modal="true">
            <div class="w-full max-w-sm rounded-box bg-base-100 p-4 shadow-xl">
              <h3 class="text-base font-semibold">{p().title}</h3>
              <Show when={p().message}>
                <p class="mt-2 text-sm text-base-content/70">{p().message}</p>
              </Show>
              <div class="mt-4 flex justify-end gap-2">
                <button type="button" class="btn btn-ghost btn-sm" onClick={() => settle(false)}>
                  {p().cancelText ?? '取消'}
                </button>
                <button
                  type="button"
                  class={`btn btn-sm ${p().danger ? 'btn-error' : 'btn-primary'}`}
                  onClick={() => settle(true)}
                >
                  {p().confirmText ?? '确认'}
                </button>
              </div>
            </div>
          </div>
        )}
      </Show>
    </FeedbackCtx.Provider>
  );
}

export function useFeedback(): FeedbackApi {
  const ctx = useContext(FeedbackCtx);
  if (!ctx) throw new Error('useFeedback must be used within <FeedbackProvider>');
  return ctx;
}

/** 兼容别名：既有页面逐步迁移到 useFeedback。 */
export function useToast(): Pick<FeedbackApi, 'show'> {
  return useFeedback();
}
