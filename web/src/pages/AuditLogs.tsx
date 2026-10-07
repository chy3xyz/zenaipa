import { createSignal, Show } from 'solid-js';

import { listAuditLogs, type AuditLogItem } from '#ui/api';
import {
  AdminCrudPage,
  DataTable,
  SearchBar,
  type Column,
  type SearchValues,
} from '#ui/components';
import { usePaged } from '#ui/hooks/usePaged';
import { formatDateTime } from '#ui/utils';

const PAGE_SIZE = 20;

const ACTION_LABELS: Record<string, string> = {
  'auth.login': '登录',
  'auth.login.fail': '登录失败',
  'auth.register': '注册',
  'user.create': '创建用户',
  'user.update': '更新用户',
  'user.delete': '删除用户',
  'task.retry': '重试任务',
  'task.cancel': '取消任务',
  'task.purge': '清理任务',
  'task.delete': '删除任务',
  'tenant.create': '创建租户',
  'tenant.update': '更新租户',
  'file.delete': '删除文件',
};

function actionLabel(action: string): string {
  return ACTION_LABELS[action] ?? action;
}

interface AuditFilters {
  actor: number;
  action: string;
  keyword: string;
}

function AuditLogs() {
  const [filters, setFilters] = createSignal<AuditFilters>({ actor: 0, action: '', keyword: '' });

  const paged = usePaged<AuditLogItem>(
    (page, pageSize) =>
      listAuditLogs(page, pageSize, {
        actor: filters().actor || undefined,
        action: filters().action || undefined,
        keyword: filters().keyword || undefined,
      }),
    { pageSize: PAGE_SIZE, watch: () => filters() },
  );

  const onSearch = (values: SearchValues) => {
    const actorId = Number.parseInt(String(values.actor ?? '').trim(), 10);
    setFilters({
      actor: Number.isFinite(actorId) ? actorId : 0,
      action: String(values.action ?? '').trim(),
      keyword: String(values.keyword ?? '').trim(),
    });
  };

  const columns: Column<AuditLogItem>[] = [
    { key: 'id', title: 'ID', render: (r) => <span class="font-mono text-xs">{r.id}</span> },
    {
      key: 'action',
      title: '操作',
      render: (r) => (
        <span class={`badge badge-sm ${r.success ? 'badge-ghost' : 'badge-error'}`}>{actionLabel(r.action)}</span>
      ),
    },
    {
      key: 'actor',
      title: '操作者',
      render: (r) => (
        <span>
          {r.actor_name || `#${r.actor_user_id}`}
          <span class="ml-1 text-xs text-base-content/40">({r.actor_user_id})</span>
        </span>
      ),
    },
    {
      key: 'target',
      title: '对象',
      render: (r) => (
        <span class="text-sm">
          {r.target_type || '-'}
          <Show when={r.target_id > 0}>
            <span class="font-mono text-xs text-base-content/50"> #{r.target_id}</span>
          </Show>
        </span>
      ),
    },
    { key: 'detail', title: '详情', render: (r) => <span class="text-sm text-base-content/80">{r.detail}</span> },
    { key: 'ip', title: 'IP', render: (r) => <span class="font-mono text-xs">{r.ip || '-'}</span> },
    {
      key: 'created_at',
      title: '时间',
      render: (r) => <span class="text-sm text-base-content/70">{formatDateTime(r.created_at)}</span>,
    },
  ];

  return (
    <AdminCrudPage
      title="审计日志"
      description="敏感操作与登录记录"
      total={paged.total()}
      onRefresh={() => void paged.refresh()}
      filter={
        <SearchBar
          fields={[
            { key: 'actor', label: '操作者 ID', type: 'number', placeholder: '操作者 ID' },
            { key: 'action', label: '操作类型', type: 'text', placeholder: '如 user.' },
            { key: 'keyword', label: '关键词', type: 'text', placeholder: '搜索详情' },
          ]}
          onSearch={onSearch}
        />
      }
    >
      <DataTable
        columns={columns}
        rows={paged.items()}
        rowKey={(r) => String(r.id)}
        total={paged.total()}
        page={paged.page()}
        totalPages={paged.totalPages()}
        loading={paged.loading()}
        error={paged.error()}
        pageSize={paged.pageSize()}
        onPageSizeChange={(n) => void paged.changePageSize(n)}
        emptyText="暂无审计记录"
        onPageChange={(p) => void paged.reload(p)}
      />
    </AdminCrudPage>
  );
}

export default AuditLogs;
