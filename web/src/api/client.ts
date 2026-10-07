import axios, { type InternalAxiosRequestConfig } from 'axios';

import { ApiError, unwrapEnvelope, type ApiEnvelope } from '#ui/api/envelope';
import { APP_CONFIG } from '#ui/config';

let authToken: string | null = null;

export function setAuthToken(token: string | null) {
  authToken = token;
}

export function getAuthToken() {
  return authToken;
}

type UnauthorizedHandler = () => void;
let unauthorizedHandler: UnauthorizedHandler | null = null;

/**
 * Register a callback fired when an authenticated API call fails with 401
 * (expired/revoked token). The auth provider wires this up to clear the
 * session and redirect to sign-in.
 */
export function setUnauthorizedHandler(fn: UnauthorizedHandler | null) {
  unauthorizedHandler = fn;
}

/** Shared HTTP client for the zenaipa backend. */
export const http = axios.create({
  baseURL: APP_CONFIG.apiBaseUrl || undefined,
  timeout: 30_000,
  headers: {
    Accept: 'application/json',
    'Content-Type': 'application/json',
  },
});

http.interceptors.request.use((config: InternalAxiosRequestConfig) => {
  if (authToken) {
    config.headers.Authorization = `Bearer ${authToken}`;
  }
  return config;
});

http.interceptors.response.use(
  (response) => response,
  (error) => {
    const status = error.response?.status as number | undefined;
    const url = String(error.config?.url ?? '');
    // A 401 on login/register is a business failure (bad credentials), not a
    // session expiry — do not force logout for those.
    const isAuthRequest = url.includes('/auth/login') || url.includes('/auth/register');
    if (status === 401 && !isAuthRequest) {
      setAuthToken(null);
      unauthorizedHandler?.();
    }
    // 非 2xx 响应体仍是 envelope 形状：解出服务端 msg 抛 ApiError，
    // 否则 UI 只能看到 axios 的 "Request failed with status code 400"。
    const data = error.response?.data;
    if (data && typeof data.code === 'number' && typeof data.msg === 'string' && data.msg) {
      return Promise.reject(new ApiError(data.code, data.msg));
    }
    return Promise.reject(error);
  },
);

/** GET 并解信封：code≠0 抛 ApiError(服务端 msg)。 */
export async function getEnvelope<T>(path: string): Promise<T> {
  const { data } = await http.get<ApiEnvelope<T>>(path);
  return unwrapEnvelope(data);
}

export async function postEnvelope<T>(path: string, body: unknown = {}): Promise<T> {
  const { data } = await http.post<ApiEnvelope<T>>(path, body);
  return unwrapEnvelope(data);
}

export async function putEnvelope<T>(path: string, body: unknown): Promise<T> {
  const { data } = await http.put<ApiEnvelope<T>>(path, body);
  return unwrapEnvelope(data);
}

export async function deleteEnvelope<T>(path: string): Promise<T> {
  const { data } = await http.delete<ApiEnvelope<T>>(path);
  return unwrapEnvelope(data);
}

/** 把任意抛出的值规整成 ApiError（供 catch 里统一取 `.message` 展示）。 */
export function toApiError(err: unknown): ApiError {
  if (err instanceof ApiError) return err;
  const msg = err instanceof Error ? err.message : String(err);
  return new ApiError(-1, msg);
}
