/**
 * Central config, read once at boot so a missing variable fails loudly at
 * startup rather than on the first user's conversion.
 */

function int(name, fallback) {
  const raw = process.env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number.parseInt(raw, 10);
  if (Number.isNaN(value)) {
    throw new Error(`${name} must be an integer, got "${raw}"`);
  }
  return value;
}

export const config = {
  port: int('PORT', 8080),
  nodeEnv: process.env.NODE_ENV || 'development',

  stirling: {
    baseUrl: (process.env.STIRLING_BASE_URL || '').replace(/\/+$/, ''),
    apiKey: process.env.STIRLING_API_KEY || '',
    timeoutMs: int('STIRLING_TIMEOUT_MS', 120_000),
  },

  quota: {
    freeMonthlyLimit: int('FREE_MONTHLY_LIMIT', 100),
  },

  upload: {
    maxBytes: int('MAX_UPLOAD_MB', 50) * 1024 * 1024,
    maxFiles: int('MAX_FILES_PER_REQUEST', 20),
  },

  corsOrigins: (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((o) => o.trim())
    .filter(Boolean),

  rateLimitPerMinute: int('RATE_LIMIT_PER_MINUTE', 30),
};

export function assertConfig() {
  if (!config.stirling.baseUrl) {
    throw new Error('STIRLING_BASE_URL is required');
  }
  if (
    !process.env.FIREBASE_SERVICE_ACCOUNT_B64 &&
    !process.env.FIREBASE_SERVICE_ACCOUNT_JSON &&
    !process.env.GOOGLE_APPLICATION_CREDENTIALS
  ) {
    throw new Error(
      'No Firebase credentials. Set FIREBASE_SERVICE_ACCOUNT_B64 (preferred), ' +
        'FIREBASE_SERVICE_ACCOUNT_JSON, or GOOGLE_APPLICATION_CREDENTIALS.',
    );
  }
}
