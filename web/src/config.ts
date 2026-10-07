/** App runtime config. */
function env(key: string, fallback = ''): string {
  const value = import.meta.env[key];
  return typeof value === 'string' && value.length > 0 ? value : fallback;
}

export const APP_CONFIG = {
  /** zenaipa backend origin；开发态留空走 rsbuild 代理(dev 3001 → 8000)，生产填完整 origin */
  apiBaseUrl: env('PUBLIC_API_BASE_URL', ''),
  /** API path prefix registered by the Zig backend */
  apiPrefix: env('PUBLIC_API_PREFIX', '/api/v1'),
  storage: {
    token: 'zenaipa.token',
    user: 'zenaipa.user',
  },
} as const;
