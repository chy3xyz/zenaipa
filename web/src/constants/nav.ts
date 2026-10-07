import { ROUTE_PATH } from '#ui/constants';

export interface NavItem {
  href: string;
  label: string;
  /** 仅管理员可见（配合 auth.user.admin）。 */
  adminOnly?: boolean;
}

/**
 * 侧边栏单一来源：路径/标题/可见性都在这张表里，MainLayout 只负责渲染。
 * 路由守卫（AdminGate）仍在 index.tsx 显式声明——两处共用 ROUTE_PATH 常量。
 */
export const NAV_ITEMS: NavItem[] = [
  { href: ROUTE_PATH.dashboard, label: '概览', adminOnly: true },
  { href: ROUTE_PATH.users, label: '用户管理', adminOnly: true },
  { href: ROUTE_PATH.aiChat, label: 'AI 助手' },
  { href: ROUTE_PATH.aiAdmin, label: 'AI 管理', adminOnly: true },
  { href: ROUTE_PATH.auditLogs, label: '审计日志', adminOnly: true },
  { href: ROUTE_PATH.mailTemplates, label: '邮件模板', adminOnly: true },
  { href: ROUTE_PATH.tasks, label: '任务中心', adminOnly: true },
  { href: ROUTE_PATH.tenants, label: '租户管理', adminOnly: true },
  { href: ROUTE_PATH.files, label: '文件管理' },
  { href: ROUTE_PATH.profile, label: '个人资料' },
];
