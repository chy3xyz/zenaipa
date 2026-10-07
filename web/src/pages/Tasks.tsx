import { createSignal, For, onMount, Show } from 'solid-js';

import {
  cancelTask,
  deleteTask,
  listTasks,
  purgeTasks,
  retryTask,
  taskStats,
  type TaskItem,
  type TaskStats,
} from '#ui/api';
import {
  AdminCrudPage,
  DataTable,
  SearchBar,
  StatCard,
  useFeedback,
  type Column,
  type SearchValues,
} from '#ui/components';
import { usePaged } from '#ui/hooks/usePaged';
import { formatDateTime } from '#ui/utils';

const PAGE_SIZE = 20;

const STATUS_LABEL: Record<string, string> = {
  pending: '等待中',
  claimed: '执行中',
  done: '已完成',
  failed: '失败',
  canceled: '已取消',
};

const STATUS_CLASS: Record<string, string> = {
  pending: 'badge-ghost',
  claimed: 'badge-info',
  done: 'badge-success',
  failed: 'badge-error',
  canceled: 'badge-outline',
};

const STATUS_OPTIONS = Object.entries(STATUS_LABEL).map(([value, label]) => ({ value, label }));

function Tasks() {
  const feedback = useFeedback();
  const [stats, setStats] = createSignal<TaskStats | null>(null);
  const [status, setStatus] = createSignal('');

  const paged = usePaged<TaskItem>((page, pageSize) => listTasks(page, pageSize, status() || undefined), {
    pageSize: PAGE_SIZE,
    watch: () => status(),
  });

  const loadStats = async () => {
    try {
      setStats(await taskStats());
    } catch {
      // stats are decorative; keep the last known values
    }
  };

  const refresh = () => {
    void loadStats();
    void paged.refresh();
  };

  onMount(() => {
    void loadStats();
  });

  const onSearch = (values: SearchValues) => {
    setStatus((values.status as string) ?? '');
  };

  const run = (opts: { title: string; message?: string; danger?: boolean; action: () => Promise<unknown>; success: string }) => {
    void feedback.runAction({
      confirm: { title: opts.title, message: opts.message, danger: opts.danger },
      action: opts.action,
      success: opts.success,
      onDone: refresh,
    });
  };

  const columns: Column<TaskItem>[] = [
    { key: 'id', title: 'ID', render: (t) => <span class="font-mono text-xs">{t.id}</span> },
    {
      key: 'name',
      title: '任务',
      render: (t) => (
        <>
          <p class="font-medium">{t.name}</p>
          <p class="max-w-md truncate font-mono text-xs text-base-content/50">{t.payload}</p>
        </>
      ),
    },
    {
      key: 'status',
      title: '状态',
      render: (t) => (
        <span class={`badge badge-sm ${STATUS_CLASS[t.status] ?? 'badge-ghost'}`}>
          {STATUS_LABEL[t.status] ?? t.status}
        </span>
      ),
    },
    {
      key: 'attempts',
      title: '尝试',
      render: (t) => <span class="text-sm">{t.attempts}/{t.max_attempts}</span>,
    },
    {
      key: 'last_error',
      title: '错误信息',
      render: (t) => <span class="max-w-xs truncate text-sm text-error">{t.last_error || '-'}</span>,
    },
    {
      key: 'created_at',
      title: '创建时间',
      render: (t) => <span class="text-sm text-base-content/70">{formatDateTime(t.created_at)}</span>,
    },
  ];

  return (
    <AdminCrudPage
      title="任务中心"
      description="后台任务队列（邮件发送、定时清理等）"
      total={paged.total()}
      onRefresh={refresh}
      extra={
        <button
          type="button"
          class="btn btn-outline btn-sm"
          onClick={() =>
            run({
              title: '清理已完成任务',
              message: '将删除所有已完成/已取消的任务记录，确定继续吗？',
              danger: true,
              action: purgeTasks,
              success: '已清理',
            })
          }
        >
          清理已完成
        </button>
      }
      filter={
        <SearchBar
          fields={[{ key: 'status', label: '状态', type: 'select', options: STATUS_OPTIONS }]}
          onSearch={onSearch}
        />
      }
    >
      <div class="space-y-4">
        <Show when={stats()}>
          <div class="grid grid-cols-2 gap-3 md:grid-cols-5">
            <For
              each={[
                { label: '等待中', value: stats()!.pending },
                { label: '执行中', value: stats()!.claimed },
                { label: '已完成', value: stats()!.done },
                { label: '失败', value: stats()!.failed },
                { label: '已取消', value: stats()!.canceled },
              ]}
            >
              {(s) => <StatCard label={s.label} value={s.value} />}
            </For>
          </div>
        </Show>

        <DataTable
          columns={columns}
          rows={paged.items()}
          rowKey={(t) => t.id}
          total={paged.total()}
          page={paged.page()}
          totalPages={paged.totalPages()}
          loading={paged.loading()}
          error={paged.error()}
          pageSize={paged.pageSize()}
          onPageSizeChange={(n) => void paged.changePageSize(n)}
          emptyText="暂无任务"
          onPageChange={(p) => void paged.reload(p)}
          actions={(task) => (
            <>
              <Show when={task.status === 'failed'}>
                <button
                  type="button"
                  class="btn btn-ghost btn-xs"
                  onClick={() => run({ title: '重试任务', action: () => retryTask(task.id), success: '已重新入队' })}
                >
                  重试
                </button>
              </Show>
              <Show when={task.status === 'pending'}>
                <button
                  type="button"
                  class="btn btn-ghost btn-xs"
                  onClick={() => run({ title: '取消任务', action: () => cancelTask(task.id), success: '已取消' })}
                >
                  取消
                </button>
              </Show>
              <button
                type="button"
                class="btn btn-ghost btn-xs text-error"
                onClick={() =>
                  run({
                    title: '删除任务',
                    message: `确定删除任务 #${task.id} 吗？`,
                    danger: true,
                    action: () => deleteTask(task.id),
                    success: '已删除',
                  })
                }
              >
                删除
              </button>
            </>
          )}
        />
      </div>
    </AdminCrudPage>
  );
}

export default Tasks;
