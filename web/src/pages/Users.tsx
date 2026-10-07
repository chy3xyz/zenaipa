import { createSignal } from 'solid-js';

import { deleteUser, listUsers, revokeUserSessions, type AuthUser } from '#ui/api';
import {
  AdminCrudPage,
  DataTable,
  SearchBar,
  useFeedback,
  type Column,
  type SearchValues,
} from '#ui/components';
import UserFormModal, { type UserFormTarget } from '#ui/components/UserFormModal';
import { useAuth } from '#ui/hooks';
import { usePaged } from '#ui/hooks/usePaged';
import { formatDateTime } from '#ui/utils';

const PAGE_SIZE = 20;

function Users() {
  const feedback = useFeedback();
  const [auth] = useAuth();
  const [keyword, setKeyword] = createSignal('');

  const [modalOpen, setModalOpen] = createSignal(false);
  const [modalMode, setModalMode] = createSignal<UserFormTarget>('create');
  const [modalUser, setModalUser] = createSignal<AuthUser | null>(null);

  const paged = usePaged<AuthUser>((page, pageSize) => listUsers(page, pageSize, keyword()), {
    pageSize: PAGE_SIZE,
    watch: () => keyword(),
  });

  const onSearch = (values: SearchValues) => {
    setKeyword((values.keyword as string) ?? '');
  };

  const openCreate = () => {
    setModalMode('create');
    setModalUser(null);
    setModalOpen(true);
  };

  const openEdit = (user: AuthUser) => {
    setModalMode('edit');
    setModalUser(user);
    setModalOpen(true);
  };

  const onRemove = (user: AuthUser) => {
    void feedback.runAction({
      confirm: { title: '删除用户', message: `确定删除用户「${user.name}」吗？此操作不可恢复。`, danger: true },
      action: () => deleteUser(user.id),
      success: '已删除',
      onDone: () => paged.refresh(),
    });
  };

  const onRevoke = (user: AuthUser) => {
    void feedback.runAction({
      confirm: { title: '踢下线', message: `确定踢下线「${user.name}」?其所有登录将立即失效` },
      action: () => revokeUserSessions(user.id),
      success: '已踢下线',
      onDone: () => paged.refresh(),
    });
  };

  const columns: Column<AuthUser>[] = [
    { key: 'id', title: 'ID', render: (u) => <span class="font-mono text-xs">{u.id}</span> },
    { key: 'name', title: '姓名', render: (u) => u.name },
    { key: 'email', title: '邮箱', render: (u) => <span class="text-sm">{u.email}</span> },
    {
      key: 'admin',
      title: '角色',
      render: (u) => (
        <span class={`badge badge-sm ${u.admin ? 'badge-primary' : 'badge-ghost'}`}>
          {u.admin ? '管理员' : '用户'}
        </span>
      ),
    },
    {
      key: 'verified',
      title: '状态',
      render: (u) => (
        <span class={`badge badge-sm ${u.verified ? 'badge-success' : 'badge-outline'}`}>
          {u.verified ? '已验证' : '未验证'}
        </span>
      ),
    },
    {
      key: 'tenant_id',
      title: '租户',
      render: (u) => <span class="badge badge-sm badge-ghost font-mono">{u.tenant_id}</span>,
    },
    {
      key: 'created_at',
      title: '创建时间',
      render: (u) => <span class="text-sm text-base-content/70">{formatDateTime(u.created_at)}</span>,
    },
  ];

  return (
    <AdminCrudPage
      title="用户管理"
      description="平台用户账号与角色"
      total={paged.total()}
      onRefresh={() => void paged.refresh()}
      onCreate={openCreate}
      createLabel="新建用户"
      filter={
        <SearchBar
          fields={[{ key: 'keyword', label: '关键词', type: 'text', placeholder: '搜索姓名或邮箱' }]}
          onSearch={onSearch}
        />
      }
    >
      <DataTable
        columns={columns}
        rows={paged.items()}
        rowKey={(u) => u.id}
        total={paged.total()}
        page={paged.page()}
        totalPages={paged.totalPages()}
        loading={paged.loading()}
        error={paged.error()}
        pageSize={paged.pageSize()}
        onPageSizeChange={(n) => void paged.changePageSize(n)}
        emptyText="暂无用户"
        onPageChange={(p) => void paged.reload(p)}
        actions={(user) => (
          <>
            <button
              type="button"
              class="btn btn-ghost btn-xs"
              onClick={() => openEdit(user)}
              disabled={user.id === auth.user?.id}
            >
              编辑
            </button>
            <button
              type="button"
              class="btn btn-ghost btn-xs text-error"
              onClick={() => onRemove(user)}
              disabled={user.id === auth.user?.id}
            >
              删除
            </button>
            <button
              type="button"
              class="btn btn-ghost btn-xs text-warning"
              onClick={() => onRevoke(user)}
              disabled={user.id === auth.user?.id}
            >
              踢下线
            </button>
          </>
        )}
      />

      <UserFormModal
        open={modalOpen()}
        mode={modalMode()}
        user={modalUser()}
        onClose={() => setModalOpen(false)}
        onSaved={() => void paged.refresh()}
      />
    </AdminCrudPage>
  );
}

export default Users;
