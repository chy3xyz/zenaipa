import { createSignal } from 'solid-js';

import { deleteFile, downloadFile, listFiles, uploadFile, type FileItem } from '#ui/api';
import { AdminCrudPage, DataTable, useFeedback, type Column } from '#ui/components';
import { usePaged } from '#ui/hooks/usePaged';
import { formatDateTime } from '#ui/utils';

const PAGE_SIZE = 20;

function formatSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / 1024 / 1024).toFixed(1)} MB`;
}

function Files() {
  const feedback = useFeedback();
  const [uploading, setUploading] = createSignal(false);

  const paged = usePaged<FileItem>((page, pageSize) => listFiles(page, pageSize), { pageSize: PAGE_SIZE });

  const onUpload = async (e: Event) => {
    const input = e.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    setUploading(true);
    try {
      await uploadFile(file);
      feedback.show(`「${file.name}」上传成功`, 'success');
      input.value = '';
      void paged.reload(1);
    } catch (err) {
      feedback.show(err instanceof Error ? err.message : '上传失败，请稍后重试', 'error');
    } finally {
      setUploading(false);
    }
  };

  const onDownload = (file: FileItem) => {
    void feedback.runAction({ action: () => downloadFile(file.id, file.name) });
  };

  const onDelete = (file: FileItem) => {
    void feedback.runAction({
      confirm: { title: '删除文件', message: `确定删除「${file.name}」吗？此操作不可恢复。`, danger: true },
      action: () => deleteFile(file.id),
      success: '已删除',
      onDone: () => paged.refresh(),
    });
  };

  const columns: Column<FileItem>[] = [
    { key: 'id', title: 'ID', render: (f) => <span class="font-mono text-xs">{f.id}</span> },
    { key: 'name', title: '文件名', render: (f) => <span class="max-w-xs truncate">{f.name}</span> },
    { key: 'mime', title: '类型', render: (f) => <span class="font-mono text-xs">{f.mime}</span> },
    { key: 'size_bytes', title: '大小', render: (f) => <span class="text-sm">{formatSize(f.size_bytes)}</span> },
    {
      key: 'created_at',
      title: '上传时间',
      render: (f) => <span class="text-sm text-base-content/70">{formatDateTime(f.created_at)}</span>,
    },
  ];

  return (
    <AdminCrudPage
      title="文件管理"
      description="平台内上传的附件与静态文件"
      total={paged.total()}
      onRefresh={() => void paged.refresh()}
      extra={
        <label class="btn btn-primary btn-sm">
          {uploading() ? '上传中…' : '上传文件'}
          <input type="file" class="hidden" disabled={uploading()} onChange={onUpload} />
        </label>
      }
    >
      <DataTable
        columns={columns}
        rows={paged.items()}
        rowKey={(f) => f.id}
        total={paged.total()}
        page={paged.page()}
        totalPages={paged.totalPages()}
        loading={paged.loading()}
        error={paged.error()}
        pageSize={paged.pageSize()}
        onPageSizeChange={(n) => void paged.changePageSize(n)}
        emptyText="暂无文件"
        onPageChange={(p) => void paged.reload(p)}
        actions={(file) => (
          <>
            <button type="button" class="btn btn-ghost btn-xs" onClick={() => onDownload(file)}>
              下载
            </button>
            <button type="button" class="btn btn-ghost btn-xs text-error" onClick={() => onDelete(file)}>
              删除
            </button>
          </>
        )}
      />
    </AdminCrudPage>
  );
}

export default Files;
