import { createEffect, createSignal } from 'solid-js';

import { createTenant, listTenants, updateTenant, type TenantItem } from '#ui/api';
import {
  AdminCrudPage,
  DataTable,
  FormField,
  FormModal,
  useFeedback,
  type Column,
} from '#ui/components';
import { usePaged } from '#ui/hooks/usePaged';
import { formatDateTime } from '#ui/utils';

const PAGE_SIZE = 20;

function Tenants() {
  const feedback = useFeedback();
  const [createOpen, setCreateOpen] = createSignal(false);
  const [name, setName] = createSignal('');
  const [creating, setCreating] = createSignal(false);
  const [createError, setCreateError] = createSignal<string | null>(null);

  const paged = usePaged<TenantItem>((page, pageSize) => listTenants(page, pageSize), { pageSize: PAGE_SIZE });

  createEffect(() => {
    if (createOpen()) {
      setName('');
      setCreating(false);
      setCreateError(null);
    }
  });

  const onCreate = async () => {
    if (creating()) return;
    setCreating(true);
    setCreateError(null);
    try {
      await createTenant({ name: name().trim() });
      feedback.show('租户已创建', 'success');
      setCreateOpen(false);
      void paged.reload(1);
    } catch (err) {
      setCreateError(err instanceof Error ? err.message : '创建失败，请稍后重试');
    } finally {
      setCreating(false);
    }
  };

  const onToggle = (tenant: TenantItem) => {
    const disabling = tenant.status === 'active';
    void feedback.runAction({
      confirm: {
        title: disabling ? '停用租户' : '启用租户',
        message: `确定${disabling ? '停用' : '启用'}租户「${tenant.name}」吗？`,
        danger: disabling,
      },
      action: () => updateTenant(tenant.id, { status: disabling ? 'disabled' : 'active' }),
      success: `租户「${tenant.name}」已${disabling ? '停用' : '启用'}`,
      onDone: () => paged.refresh(),
    });
  };

  const columns: Column<TenantItem>[] = [
    { key: 'id', title: 'ID', render: (t) => <span class="font-mono text-xs">{t.id}</span> },
    { key: 'name', title: '名称', render: (t) => <span class="font-medium">{t.name}</span> },
    {
      key: 'status',
      title: '状态',
      render: (t) => (
        <span class={`badge badge-sm ${t.status === 'active' ? 'badge-success' : 'badge-outline'}`}>
          {t.status === 'active' ? '启用' : '停用'}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '创建时间',
      render: (t) => <span class="text-sm text-base-content/70">{formatDateTime(t.created_at)}</span>,
    },
  ];

  return (
    <AdminCrudPage
      title="租户管理"
      description="多租户隔离：每个租户拥有独立的用户与数据"
      total={paged.total()}
      onRefresh={() => void paged.refresh()}
      onCreate={() => setCreateOpen(true)}
    >
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
        emptyText="暂无租户"
        onPageChange={(p) => void paged.reload(p)}
        actions={(tenant) => (
          <button
            type="button"
            class={`btn btn-ghost btn-xs ${tenant.status === 'active' ? 'text-error' : ''}`}
            onClick={() => onToggle(tenant)}
          >
            {tenant.status === 'active' ? '停用' : '启用'}
          </button>
        )}
      />

      <FormModal
        open={createOpen()}
        title="新建租户"
        error={createError()}
        submitting={creating()}
        submitLabel="创建"
        onSubmit={() => void onCreate()}
        onClose={() => setCreateOpen(false)}
      >
        <FormField label="租户名称" required>
          <input
            type="text"
            class="input input-bordered input-sm w-full"
            placeholder="例如：Acme Inc"
            value={name()}
            onInput={(e) => setName(e.currentTarget.value)}
            required
          />
        </FormField>
      </FormModal>
    </AdminCrudPage>
  );
}

export default Tenants;
