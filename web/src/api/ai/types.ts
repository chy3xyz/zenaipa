import type { PageResult } from '#ui/api/envelope';

export interface AiProviderItem {
  id: number;
  name: string;
  endpoint: string;
  models: string;
  fallback_providers: string;
  enabled: boolean;
  has_keys: boolean;
  created_at: number;
  updated_at: number;
}

export interface AiProviderListResult extends PageResult<AiProviderItem> {}

export interface AiSessionItem {
  id: number;
  title: string;
  created_at: number;
  updated_at: number;
}

export interface AiSessionListResult extends PageResult<AiSessionItem> {}

export interface AiMessageItem {
  id: number;
  role: 'user' | 'assistant' | 'tool';
  content: string;
  reasoning_content: string;
  created_at: number;
}

export interface AiMessageListResult {
  list: AiMessageItem[];
  total: number;
}

export interface AiChatResult {
  answer: string;
  reasoning_content: string;
  budget_exhausted: boolean;
}

export interface AiApprovalItem {
  id: number;
  session_id: number;
  requested_by: number;
  skill_name: string;
  args: string;
  status: 'pending' | 'approved' | 'rejected';
  created_at: number;
}

export interface AiApprovalListResult extends PageResult<AiApprovalItem> {}

export interface AiRunItem {
  id: number;
  session_id: number;
  user_id: number;
  kind: string;
  prompt: string;
  model: string;
  tokens_in: number;
  tokens_out: number;
  steps: number;
  tool_calls: number;
  tool_errors: number;
  status: string;
  err: string;
  created_at: number;
}

export interface AiRunListResult extends PageResult<AiRunItem> {}

export interface AiWorkflowStep {
  name: string;
  status: string;
  output: string;
}

export interface AiWorkflowResult {
  status: string;
  steps: AiWorkflowStep[];
}
