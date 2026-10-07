import { A } from '@solidjs/router';
import { For, Show, createEffect, createSignal, onCleanup, onMount, type JSX } from 'solid-js';

import {
  deleteNotification,
  listNotifications,
  markAllRead,
  markRead,
  unreadCount,
  type NotificationItem,
} from '#ui/api';
import { useFeedback } from '#ui/components';
import { NAV_ITEMS } from '#ui/constants/nav';
import { useAuth } from '#ui/hooks';
import { formatDateTime } from '#ui/utils';

const NAV_LINK_CLASS =
  'block rounded-lg px-3 py-2 text-sm hover:bg-base-300 [&.active]:bg-primary [&.active]:text-primary-content';

function NotificationBell() {
  const feedback = useFeedback();
  const [open, setOpen] = createSignal(false);
  const [unread, setUnread] = createSignal(0);
  const [items, setItems] = createSignal<NotificationItem[]>([]);

  const refresh = async () => {
    try {
      const [count, result] = await Promise.all([unreadCount(), listNotifications(1, 8)]);
      setUnread(count);
      setItems(result.list);
    } catch {
      // keep previous state on transient errors
    }
  };

  onMount(() => {
    void refresh();
    const timer = window.setInterval(() => void refresh(), 30_000);
    onCleanup(() => window.clearInterval(timer));
  });

  const onMarkRead = async (id: number) => {
    try {
      await markRead(id);
      await refresh();
    } catch (err) {
      feedback.show(toMessage(err), 'error');
    }
  };

  const onMarkAll = async () => {
    try {
      await markAllRead();
      await refresh();
    } catch (err) {
      feedback.show(toMessage(err), 'error');
    }
  };

  const onDelete = async (id: number) => {
    try {
      await deleteNotification(id);
      await refresh();
    } catch (err) {
      feedback.show(toMessage(err), 'error');
    }
  };

  return (
    <div class="relative">
      <button
        type="button"
        class="btn btn-ghost btn-circle btn-sm relative"
        onClick={() => {
          setOpen(!open());
          if (!open()) void refresh();
        }}
        aria-label="通知"
      >
        <span class="text-base">🔔</span>
        <Show when={unread() > 0}>
          <span class="badge badge-error badge-xs absolute -top-0.5 -right-0.5">
            {unread() > 99 ? '99+' : unread()}
          </span>
        </Show>
      </button>

      <Show when={open()}>
        <div class="absolute right-0 z-50 mt-2 w-80 rounded-lg border border-base-300 bg-base-100 shadow-xl">
          <div class="flex items-center justify-between border-b border-base-300 px-3 py-2">
            <span class="text-sm font-semibold">通知</span>
            <button type="button" class="btn btn-ghost btn-xs" onClick={onMarkAll}>
              全部已读
            </button>
          </div>
          <div class="max-h-80 overflow-y-auto">
            <Show
              when={items().length > 0}
              fallback={<p class="px-3 py-6 text-center text-sm text-base-content/50">暂无通知</p>}
            >
              <For each={items()}>
                {(item) => (
                  <div class={`border-b border-base-200 px-3 py-2 ${item.read ? 'opacity-60' : ''}`}>
                    <div class="flex items-start justify-between gap-2">
                      <div class="min-w-0">
                        <p class="truncate text-sm font-medium">{item.title}</p>
                        <p class="truncate text-xs text-base-content/60">{item.body}</p>
                        <p class="mt-0.5 text-xs text-base-content/40">{formatDateTime(item.created_at)}</p>
                      </div>
                      <div class="flex shrink-0 gap-1">
                        <Show when={!item.read}>
                          <button type="button" class="btn btn-ghost btn-xs" onClick={() => onMarkRead(item.id)}>
                            已读
                          </button>
                        </Show>
                        <button type="button" class="btn btn-ghost btn-xs text-error" onClick={() => onDelete(item.id)}>
                          删除
                        </button>
                      </div>
                    </div>
                  </div>
                )}
              </For>
            </Show>
          </div>
        </div>
      </Show>
    </div>
  );
}

function toMessage(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

function preferredDark(): boolean {
  const saved = localStorage.getItem('zenaipa.theme');
  if (saved === 'dark' || saved === 'light') return saved === 'dark';
  return window.matchMedia('(prefers-color-scheme: dark)').matches;
}

function MainLayout(props: { children?: JSX.Element }) {
  const [auth, actions] = useAuth();
  // 主题默认跟系统：无本地偏好时按 prefers-color-scheme 初始化（手动切换仍持久化）。
  const [dark, setDark] = createSignal(preferredDark());
  createEffect(() => {
    document.documentElement.setAttribute('data-theme', dark() ? 'dark' : 'light');
    localStorage.setItem('zenaipa.theme', dark() ? 'dark' : 'light');
  });
  const toggleTheme = () => setDark((d) => !d);

  return (
    <div class="flex h-screen overflow-hidden bg-base-100">
      <aside class="flex w-56 shrink-0 flex-col border-r border-base-300 bg-base-200">
        <div class="flex h-16 items-center gap-2 border-b border-base-300 px-4">
          <span class="text-lg font-bold">Zenaipa</span>
        </div>
        <nav class="flex-1 space-y-1 p-3">
          <For each={NAV_ITEMS}>
            {(item) => (
              <Show when={!item.adminOnly || auth.user?.admin}>
                <A href={item.href} class={NAV_LINK_CLASS} activeClass="active">
                  {item.label}
                </A>
              </Show>
            )}
          </For>
        </nav>
        <div class="border-t border-base-300 p-3">
          <button type="button" class="btn btn-outline btn-sm w-full" onClick={() => actions.logout()}>
            退出登录
          </button>
        </div>
      </aside>

      <div class="flex flex-1 flex-col overflow-hidden">
        <header class="flex h-16 items-center justify-between border-b border-base-300 px-6">
          <h1 class="text-base font-semibold">管理后台</h1>
          <div class="flex items-center gap-3 text-sm text-base-content/70">
            <NotificationBell />
            <button type="button" class="btn btn-ghost btn-xs" onClick={toggleTheme} aria-label="切换主题">
              {dark() ? '🌙' : '☀️'}
            </button>
            <span class="badge badge-ghost">{auth.user?.name ?? '-'}</span>
            <span class="badge badge-outline">{auth.user?.admin ? '管理员' : '用户'}</span>
          </div>
        </header>
        <main class="flex-1 overflow-y-auto p-6">{props.children}</main>
      </div>
    </div>
  );
}

export default MainLayout;
