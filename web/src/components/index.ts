/**
 * 通用组件 barrel：页面统一从这里取（`#ui/components`），不再深路径散引。
 * 域组件（UserFormModal 等）不进此 barrel。
 */
export { BaseModal, type ModalSize } from '#ui/components/BaseModal';
export { AdminCrudPage } from '#ui/components/AdminCrudPage';
export { default as DataTable, type Column } from '#ui/components/DataTable';
export { EmptyState } from '#ui/components/EmptyState';
export { FeedbackProvider, useFeedback, useToast, type ConfirmOptions, type FeedbackApi } from '#ui/components/Feedback';
export { FormField } from '#ui/components/FormField';
export { FormModal } from '#ui/components/FormModal';
export { Pagination, DEFAULT_PAGE_SIZES } from '#ui/components/Pagination';
export { SearchBar, type SearchField, type SearchValues } from '#ui/components/SearchBar';
export { StatCard } from '#ui/components/StatCard';
export { default as UserFormModal } from '#ui/components/UserFormModal';
