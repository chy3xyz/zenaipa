import { createSignal } from 'solid-js';

import { listMailTemplates, upsertMailTemplate, type MailTemplateItem } from '#ui/api';
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

const PAGE_SIZE = 50;

const CODE_LABELS: Record<string, string> = {
  verify_email: '邮箱验证',
  reset_password: '密码重置',
};

function MailTemplates() {
  const feedback = useFeedback();
  const [editing, setEditing] = createSignal<MailTemplateItem | null>(null);
  const [subject, setSubject] = createSignal('');
  const [body, setBody] = createSignal('');
  const [saving, setSaving] = createSignal(false);
  const [error, setError] = createSignal<string | null>(null);

  const paged = usePaged<MailTemplateItem>((page, pageSize) => listMailTemplates(page, pageSize), {
    pageSize: PAGE_SIZE,
  });

  const openEdit = (item: MailTemplateItem) => {
    setSubject(item.subject);
    setBody(item.body);
    setSaving(false);
    setError(null);
    setEditing(item);
  };

  const onSave = async () => {
    const item = editing();
    if (!item || saving()) return;
    if (!subject().trim() || !body().trim()) {
      setError('主题和正文不能为空');
      return;
    }
    setSaving(true);
    setError(null);
    try {
      await upsertMailTemplate(item.code, subject(), body());
      feedback.show('模板已保存', 'success');
      setEditing(null);
      void paged.refresh();
    } catch (err) {
      setError(err instanceof Error ? err.message : '保存失败，请稍后重试');
    } finally {
      setSaving(false);
    }
  };

  const columns: Column<MailTemplateItem>[] = [
    {
      key: 'code',
      title: '模板',
      render: (item) => (
        <span>
          <span class="badge badge-ghost">{CODE_LABELS[item.code] ?? item.code}</span>
          <span class="ml-1 font-mono text-xs text-base-content/50">{item.code}</span>
        </span>
      ),
    },
    { key: 'subject', title: '主题', render: (item) => <span class="max-w-xs truncate text-sm">{item.subject}</span> },
    {
      key: 'body',
      title: '正文',
      render: (item) => <span class="max-w-md truncate text-sm text-base-content/70">{item.body}</span>,
    },
    {
      key: 'updated_at',
      title: '更新时间',
      render: (item) => <span class="text-sm text-base-content/70">{formatDateTime(item.updated_at)}</span>,
    },
  ];

  return (
    <AdminCrudPage
      title="邮件模板"
      description="未配置的模板使用内置默认值；支持变量 {app_name} {link} {email}"
      total={paged.total()}
      onRefresh={() => void paged.refresh()}
    >
      <DataTable
        columns={columns}
        rows={paged.items()}
        rowKey={(item) => item.code}
        total={paged.total()}
        page={paged.page()}
        totalPages={paged.totalPages()}
        loading={paged.loading()}
        error={paged.error()}
        pageSize={paged.pageSize()}
        onPageSizeChange={(n) => void paged.changePageSize(n)}
        emptyText="暂无模板"
        onPageChange={(p) => void paged.reload(p)}
        actions={(item) => (
          <button type="button" class="btn btn-outline btn-xs" onClick={() => openEdit(item)}>
            编辑
          </button>
        )}
      />

      <FormModal
        open={editing() !== null}
        title="编辑模板"
        description={editing()?.code}
        error={error()}
        submitting={saving()}
        submitLabel="保存"
        onSubmit={() => void onSave()}
        onClose={() => setEditing(null)}
      >
        <FormField label="主题" required>
          <input
            type="text"
            class="input input-bordered input-sm w-full"
            value={subject()}
            onInput={(e) => setSubject(e.currentTarget.value)}
            required
          />
        </FormField>
        <FormField label="正文" required>
          <textarea
            class="textarea textarea-bordered textarea-sm w-full font-mono text-sm"
            rows={8}
            value={body()}
            onInput={(e) => setBody(e.currentTarget.value)}
            required
          />
        </FormField>
      </FormModal>
    </AdminCrudPage>
  );
}

export default MailTemplates;
