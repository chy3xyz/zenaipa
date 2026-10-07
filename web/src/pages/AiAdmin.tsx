import { createSignal, For, Show } from 'solid-js';

import {
  checkAiProvider,
  createAiProvider,
  deleteAiProvider,
  listAiApprovals,
  listAiProviders,
  listAiRuns,
  resolveAiApproval,
  runAiWorkflow,
  toApiError,
  updateAiProvider,
  type AiApprovalItem,
  type AiProviderItem,
  type AiRunItem,
  type AiWorkflowResult,
} from '#ui/api';
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

type Tab = 'providers' | 'approvals' | 'runs' | 'workflow';

const PAGE_SIZE = 20;

function AiAdmin() {
  const feedback = useFeedback();
  const [tab, setTab] = createSignal<Tab>('providers');

  const providersPaged = usePaged<AiProviderItem>((page, pageSize) => listAiProviders(page, pageSize), {
    pageSize: PAGE_SIZE,
  });
  const approvalsPaged = usePaged<AiApprovalItem>(
    (page, pageSize) => listAiApprovals(page, pageSize, 'pending'),
    { pageSize: PAGE_SIZE, immediate: false },
  );
  const runsPaged = usePaged<AiRunItem>((page, pageSize) => listAiRuns(page, pageSize), {
    pageSize: PAGE_SIZE,
    immediate: false,
  });

  // Provider form
  const [formOpen, setFormOpen] = createSignal(false);
  const [editing, setEditing] = createSignal<AiProviderItem | null>(null);
  const [name, setName] = createSignal('');
  const [endpoint, setEndpoint] = createSignal('');
  const [apiKeys, setApiKeys] = createSignal('');
  const [models, setModels] = createSignal('');
  const [enabled, setEnabled] = createSignal(true);
  const [saving, setSaving] = createSignal(false);
  const [saveError, setSaveError] = createSignal<string | null>(null);

  const [workflow, setWorkflow] = createSignal<AiWorkflowResult | null>(null);
  const [wfBusy, setWfBusy] = createSignal(false);
  const [checkingId, setCheckingId] = createSignal<number | null>(null);
  const [checkResult, setCheckResult] = createSignal<{ id: number; ok: boolean; msg: string } | null>(null);
  const [resolvingId, setResolvingId] = createSignal<number | null>(null);

  const switchTab = (t: Tab) => {
    setTab(t);
    if (t === 'providers') void providersPaged.reload(1);
    if (t === 'approvals') void approvalsPaged.reload(1);
    if (t === 'runs') void runsPaged.reload(1);
    if (t === 'workflow') setWorkflow(null);
  };

  const refreshActive = () => {
    if (tab() === 'providers') void providersPaged.refresh();
    if (tab() === 'approvals') void approvalsPaged.refresh();
    if (tab() === 'runs') void runsPaged.refresh();
  };

  const openCreate = () => {
    setEditing(null);
    setName('');
    setEndpoint('');
    setApiKeys('');
    setModels('');
    setEnabled(true);
    setSaving(false);
    setSaveError(null);
    setFormOpen(true);
  };

  const openEdit = (p: AiProviderItem) => {
    setEditing(p);
    setName(p.name);
    setEndpoint(p.endpoint);
    setApiKeys('');
    setModels(p.models);
    setEnabled(p.enabled);
    setSaving(false);
    setSaveError(null);
    setFormOpen(true);
  };

  const onSaveProvider = async () => {
    if (saving()) return;
    if (!name().trim() || !endpoint().trim()) {
      setSaveError('名称与端点不能为空');
      return;
    }
    setSaving(true);
    setSaveError(null);
    try {
      if (editing()) {
        await updateAiProvider(editing()!.id, {
          name: name(),
          endpoint: endpoint(),
          ...(apiKeys().trim() ? { api_keys: apiKeys() } : {}),
          models: models(),
          enabled: enabled(),
        });
      } else {
        await createAiProvider({
          name: name(),
          endpoint: endpoint(),
          api_keys: apiKeys(),
          models: models(),
          enabled: enabled(),
        });
      }
      setFormOpen(false);
      await providersPaged.refresh();
    } catch (err) {
      setSaveError(toApiError(err).message);
    } finally {
      setSaving(false);
    }
  };

  const onRemoveProvider = (p: AiProviderItem) => {
    void feedback.runAction({
      confirm: { title: '删除 Provider', message: `确定删除 Provider「${p.name}」？`, danger: true },
      action: () => deleteAiProvider(p.id),
      success: '已删除',
      onDone: () => void providersPaged.refresh(),
    });
  };

  const onCheckProvider = async (p: AiProviderItem) => {
    setCheckingId(p.id);
    setCheckResult(null);
    try {
      await checkAiProvider(p.id);
      setCheckResult({ id: p.id, ok: true, msg: '连接正常' });
    } catch (err) {
      setCheckResult({ id: p.id, ok: false, msg: toApiError(err).message });
    } finally {
      setCheckingId(null);
    }
  };

  const onResolve = async (a: AiApprovalItem, action: 'approve' | 'reject') => {
    if (resolvingId() !== null) return;
    setResolvingId(a.id);
    try {
      await resolveAiApproval(a.id, action);
      feedback.show(action === 'approve' ? '已批准' : '已拒绝', 'success');
      await approvalsPaged.refresh();
    } catch (err) {
      feedback.show(toApiError(err).message, 'error');
    } finally {
      setResolvingId(null);
    }
  };

  const onRunWorkflow = async () => {
    setWfBusy(true);
    try {
      setWorkflow(await runAiWorkflow());
    } catch (err) {
      feedback.show(toApiError(err).message, 'error');
    } finally {
      setWfBusy(false);
    }
  };

  const providerColumns: Column<AiProviderItem>[] = [
    { key: 'name', title: '名称', render: (p) => <span class="font-mono text-sm">{p.name}</span> },
    {
      key: 'endpoint',
      title: '端点',
      render: (p) => <span class="max-w-xs truncate text-sm text-base-content/70">{p.endpoint}</span>,
    },
    { key: 'models', title: '模型', render: (p) => <span class="text-sm">{p.models || '-'}</span> },
    {
      key: 'has_keys',
      title: '密钥',
      render: (p) => (
        <span class={`badge badge-sm ${p.has_keys ? 'badge-success' : 'badge-error'}`}>
          {p.has_keys ? '已配置' : '缺失'}
        </span>
      ),
    },
    {
      key: 'enabled',
      title: '状态',
      render: (p) => (
        <span class={`badge badge-sm ${p.enabled ? 'badge-primary' : 'badge-ghost'}`}>
          {p.enabled ? '启用' : '停用'}
        </span>
      ),
    },
  ];

  const approvalColumns: Column<AiApprovalItem>[] = [
    { key: 'id', title: 'ID', render: (a) => <span class="font-mono text-xs">{a.id}</span> },
    { key: 'skill_name', title: '技能', render: (a) => <span class="font-mono text-xs">{a.skill_name}</span> },
    {
      key: 'args',
      title: '参数',
      render: (a) => <span class="max-w-xs truncate font-mono text-xs text-base-content/70">{a.args}</span>,
    },
    { key: 'requested_by', title: '请求者', render: (a) => <span class="text-sm">{a.requested_by}</span> },
    {
      key: 'status',
      title: '状态',
      render: (a) => (
        <span
          class={`badge badge-sm ${
            a.status === 'pending' ? 'badge-warning' : a.status === 'approved' ? 'badge-success' : 'badge-ghost'
          }`}
        >
          {a.status === 'pending' ? '待审批' : a.status === 'approved' ? '已批准' : '已拒绝'}
        </span>
      ),
    },
    {
      key: 'created_at',
      title: '时间',
      render: (a) => <span class="text-sm text-base-content/70">{formatDateTime(a.created_at)}</span>,
    },
  ];

  const runColumns: Column<AiRunItem>[] = [
    { key: 'id', title: 'ID', render: (r) => <span class="font-mono text-xs">{r.id}</span> },
    { key: 'user_id', title: '用户', render: (r) => <span class="font-mono text-xs">{r.user_id}</span> },
    { key: 'kind', title: '类型', render: (r) => <span class="text-sm">{r.kind}</span> },
    {
      key: 'model',
      title: '模型',
      render: (r) => <span class="font-mono text-xs text-base-content/70">{r.model || '-'}</span>,
    },
    {
      key: 'prompt',
      title: '提示词',
      render: (r) => <span class="max-w-xs truncate text-sm text-base-content/70">{r.prompt}</span>,
    },
    {
      key: 'usage',
      title: '用量',
      render: (r) => (
        <span class="text-xs text-base-content/70">
          {r.tokens_in > 0 || r.tokens_out > 0 ? `${r.tokens_in}→${r.tokens_out} tok` : '—'}
          {r.steps > 0 || r.tool_calls > 0
            ? ` · ${r.steps}步/${r.tool_calls}工具${r.tool_errors > 0 ? `/${r.tool_errors}错` : ''}`
            : ''}
        </span>
      ),
    },
    {
      key: 'status',
      title: '状态',
      render: (r) => (
        <span class={`badge badge-sm ${r.status === 'ok' ? 'badge-success' : 'badge-warning'}`}>{r.status}</span>
      ),
    },
    {
      key: 'created_at',
      title: '时间',
      render: (r) => <span class="text-sm text-base-content/70">{formatDateTime(r.created_at)}</span>,
    },
  ];

  const totalForTab = () => {
    if (tab() === 'providers') return providersPaged.total();
    if (tab() === 'approvals') return approvalsPaged.total();
    if (tab() === 'runs') return runsPaged.total();
    return undefined;
  };

  return (
    <AdminCrudPage
      title="AI 管理"
      description="Provider、审批、运行记录与工作流"
      total={totalForTab()}
      onRefresh={tab() === 'workflow' ? undefined : refreshActive}
      extra={
        <>
          <div class="tabs tabs-boxed">
            <button type="button" class={`tab tab-sm ${tab() === 'providers' ? 'tab-active' : ''}`} onClick={() => switchTab('providers')}>
              Provider
            </button>
            <button type="button" class={`tab tab-sm ${tab() === 'approvals' ? 'tab-active' : ''}`} onClick={() => switchTab('approvals')}>
              审批
            </button>
            <button type="button" class={`tab tab-sm ${tab() === 'runs' ? 'tab-active' : ''}`} onClick={() => switchTab('runs')}>
              运行记录
            </button>
            <button type="button" class={`tab tab-sm ${tab() === 'workflow' ? 'tab-active' : ''}`} onClick={() => switchTab('workflow')}>
              工作流
            </button>
          </div>
          <Show when={tab() === 'providers'}>
            <button type="button" class="btn btn-primary btn-sm" onClick={openCreate}>
              新建 Provider
            </button>
          </Show>
        </>
      }
    >
      <div class="space-y-4">
        <Show when={tab() === 'providers'}>
          <div class="space-y-3">
            <DataTable
              columns={providerColumns}
              rows={providersPaged.items()}
              rowKey={(p) => p.id}
              total={providersPaged.total()}
              page={providersPaged.page()}
              totalPages={providersPaged.totalPages()}
              loading={providersPaged.loading()}
              error={providersPaged.error()}
              pageSize={providersPaged.pageSize()}
              onPageSizeChange={(n) => void providersPaged.changePageSize(n)}
              emptyText="暂无 Provider。配置一个 OpenAI 兼容端点(需设置 ZENAIPA_AI_KEY_SECRET)"
              onPageChange={(p) => void providersPaged.reload(p)}
              actions={(p) => (
                <>
                  <button
                    type="button"
                    class="btn btn-outline btn-xs"
                    disabled={checkingId() === p.id}
                    onClick={() => void onCheckProvider(p)}
                  >
                    {checkingId() === p.id ? '测试中…' : '测试'}
                  </button>
                  <button type="button" class="btn btn-outline btn-xs" onClick={() => openEdit(p)}>
                    编辑
                  </button>
                  <button type="button" class="btn btn-ghost btn-xs text-error" onClick={() => onRemoveProvider(p)}>
                    删除
                  </button>
                </>
              )}
            />
            <Show when={checkResult()}>
              {(r) => (
                <div role="alert" class={`alert py-2 text-sm ${r().ok ? 'alert-success' : 'alert-error'}`}>
                  Provider #{r().id}: {r().msg}
                </div>
              )}
            </Show>
          </div>
        </Show>

        <Show when={tab() === 'approvals'}>
          <DataTable
            columns={approvalColumns}
            rows={approvalsPaged.items()}
            rowKey={(a) => a.id}
            total={approvalsPaged.total()}
            page={approvalsPaged.page()}
            totalPages={approvalsPaged.totalPages()}
            loading={approvalsPaged.loading()}
            error={approvalsPaged.error()}
            pageSize={approvalsPaged.pageSize()}
            onPageSizeChange={(n) => void approvalsPaged.changePageSize(n)}
            emptyText="暂无待审批事项"
            onPageChange={(p) => void approvalsPaged.reload(p)}
            actions={(a) => (
              <>
                <button
                  type="button"
                  class="btn btn-success btn-xs"
                  disabled={a.status !== 'pending' || resolvingId() !== null}
                  onClick={() => void onResolve(a, 'approve')}
                >
                  {resolvingId() === a.id ? '处理中…' : '批准'}
                </button>
                <button
                  type="button"
                  class="btn btn-error btn-xs"
                  disabled={a.status !== 'pending' || resolvingId() !== null}
                  onClick={() => void onResolve(a, 'reject')}
                >
                  {resolvingId() === a.id ? '处理中…' : '拒绝'}
                </button>
              </>
            )}
          />
        </Show>

        <Show when={tab() === 'runs'}>
          <DataTable
            columns={runColumns}
            rows={runsPaged.items()}
            rowKey={(r) => r.id}
            total={runsPaged.total()}
            page={runsPaged.page()}
            totalPages={runsPaged.totalPages()}
            loading={runsPaged.loading()}
            error={runsPaged.error()}
            pageSize={runsPaged.pageSize()}
            onPageSizeChange={(n) => void runsPaged.changePageSize(n)}
            emptyText="暂无运行记录"
            onPageChange={(p) => void runsPaged.reload(p)}
          />
        </Show>

        <Show when={tab() === 'workflow'}>
          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <p class="text-sm text-base-content/60">
                演示工作流:依次执行「任务统计」→「租户列表」两个只读技能并汇总结果。
              </p>
              <button type="button" class="btn btn-primary btn-sm" disabled={wfBusy()} onClick={() => void onRunWorkflow()}>
                {wfBusy() ? '运行中…' : '运行工作流'}
              </button>
            </div>
            <Show when={workflow()}>
              {(wf) => (
                <div class="space-y-2">
                  <div>
                    状态:
                    <span class="badge badge-sm badge-ghost ml-2">{wf().status}</span>
                  </div>
                  <For each={wf().steps}>
                    {(s) => (
                      <div class="rounded-lg border border-base-300 p-3">
                        <div class="flex items-center justify-between">
                          <span class="font-mono text-sm">{s.name}</span>
                          <span class="badge badge-sm badge-ghost">{s.status}</span>
                        </div>
                        <pre class="mt-2 overflow-x-auto rounded bg-base-200 p-2 text-xs whitespace-pre-wrap">
                          {s.output}
                        </pre>
                      </div>
                    )}
                  </For>
                </div>
              )}
            </Show>
          </div>
        </Show>
      </div>

      <FormModal
        open={formOpen()}
        title={editing() ? '编辑 Provider' : '新建 Provider'}
        error={saveError()}
        submitting={saving()}
        submitLabel="保存"
        onSubmit={() => void onSaveProvider()}
        onClose={() => setFormOpen(false)}
      >
        <FormField label="名称(唯一)" required>
          <input
            type="text"
            class="input input-bordered input-sm w-full"
            value={name()}
            onInput={(e) => setName(e.currentTarget.value)}
            required
          />
        </FormField>
        <FormField label="端点(OpenAI 兼容)" required hint="需 http(s) 公网地址，如 https://api.openai.com/v1/chat/completions">
          <input
            type="text"
            class="input input-bordered input-sm w-full font-mono"
            placeholder="https://api.openai.com/v1/chat/completions"
            value={endpoint()}
            onInput={(e) => setEndpoint(e.currentTarget.value)}
            required
          />
        </FormField>
        <FormField label="API 密钥" hint='JSON 数组，如 ["sk-abc"]；编辑时留空则保持原密钥'>
          <input
            type="password"
            class="input input-bordered input-sm w-full font-mono"
            value={apiKeys()}
            onInput={(e) => setApiKeys(e.currentTarget.value)}
          />
        </FormField>
        <FormField label="模型" hint="逗号分隔，如 gpt-4o-mini,deepseek-v4-flash">
          <input
            type="text"
            class="input input-bordered input-sm w-full"
            placeholder="gpt-4o-mini,deepseek-v4-flash"
            value={models()}
            onInput={(e) => setModels(e.currentTarget.value)}
          />
        </FormField>
        <label class="flex cursor-pointer items-center gap-2 pt-1 text-sm">
          <input
            type="checkbox"
            class="checkbox checkbox-sm"
            checked={enabled()}
            onChange={(e) => setEnabled(e.currentTarget.checked)}
          />
          启用
        </label>
      </FormModal>
    </AdminCrudPage>
  );
}

export default AiAdmin;
