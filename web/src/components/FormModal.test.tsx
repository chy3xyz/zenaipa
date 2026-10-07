import { fireEvent, render, screen } from '@solidjs/testing-library';
import { describe, expect, it, vi } from 'vitest';

import { FormModal } from './FormModal';

describe('FormModal', () => {
  it('renders title and children', () => {
    render(() => (
      <FormModal open title="新建用户" onSubmit={() => {}} onClose={() => {}}>
        <div>表单内容</div>
      </FormModal>
    ));
    expect(screen.getByText('新建用户')).toBeTruthy();
    expect(screen.getByText('表单内容')).toBeTruthy();
  });

  it('renders nothing when closed', () => {
    render(() => (
      <FormModal open={false} title="隐藏弹窗" onSubmit={() => {}} onClose={() => {}}>
        <div>表单内容</div>
      </FormModal>
    ));
    expect(screen.queryByText('隐藏弹窗')).toBeNull();
    expect(screen.queryByText('表单内容')).toBeNull();
  });

  it('shows 提交中… on the submit button and disables actions while submitting', () => {
    render(() => <FormModal open title="新建用户" submitting onSubmit={() => {}} onClose={() => {}} />);
    const submit = screen.getByText('提交中…').closest('button') as HTMLButtonElement;
    expect(submit).toBeTruthy();
    expect(submit.disabled).toBe(true);
    const cancel = screen.getByText('取消').closest('button') as HTMLButtonElement;
    expect(cancel.disabled).toBe(true);
  });

  it('blocks onSubmit while submitting', () => {
    const onSubmit = vi.fn();
    const { container } = render(() => (
      <FormModal open title="守卫" submitting onSubmit={onSubmit} onClose={() => {}}>
        <span>字段</span>
      </FormModal>
    ));
    fireEvent.submit(container.querySelector('form') as HTMLFormElement);
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('calls onSubmit once on form submit when not submitting', () => {
    const onSubmit = vi.fn();
    const { container } = render(() => (
      <FormModal open title="提交" onSubmit={onSubmit} onClose={() => {}}>
        <span>字段</span>
      </FormModal>
    ));
    fireEvent.submit(container.querySelector('form') as HTMLFormElement);
    expect(onSubmit).toHaveBeenCalledTimes(1);
  });

  it('renders the error prop as an alert', () => {
    render(() => <FormModal open title="新建用户" error="名称已存在" onSubmit={() => {}} onClose={() => {}} />);
    const alert = screen.getByRole('alert');
    expect(alert.textContent).toContain('名称已存在');
  });
});
