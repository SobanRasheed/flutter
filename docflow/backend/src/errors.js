/**
 * Every error the API returns goes through here, so the Flutter client only
 * ever has to understand one JSON shape:
 *
 *   { "error": { "code": "quota_exceeded", "message": "...", ...extra } }
 *
 * The `code` is the stable contract. Flutter branches on it; the message is
 * for humans and may change.
 */
export class ApiError extends Error {
  constructor(status, code, message, extra = {}) {
    super(message);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }

  static unauthorized(message = 'Missing or invalid credentials') {
    return new ApiError(401, 'unauthenticated', message);
  }

  static badRequest(message, extra) {
    return new ApiError(400, 'bad_request', message, extra);
  }

  static notFound(message = 'Not found') {
    return new ApiError(404, 'not_found', message);
  }

  static payloadTooLarge(message) {
    return new ApiError(413, 'payload_too_large', message);
  }

  /**
   * The one the paywall listens for. 402 is the whole reason this backend
   * exists — Flutter must treat it as "show the subscription sheet", not as a
   * generic failure.
   */
  static quotaExceeded(used, limit) {
    return new ApiError(
      402,
      'quota_exceeded',
      `Free plan allows ${limit} conversions per month. Upgrade to Pro for unlimited conversions.`,
      { conversionsUsed: used, limit, isPro: false },
    );
  }

  static upstream(message, extra) {
    return new ApiError(502, 'conversion_failed', message, extra);
  }

  static timeout(message = 'The conversion engine took too long to respond') {
    return new ApiError(504, 'conversion_timeout', message);
  }

  toJSON() {
    return { error: { code: this.code, message: this.message, ...this.extra } };
  }
}

/** Wraps an async route so a rejected promise reaches the error handler. */
export const asyncRoute = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);

export function errorHandler(err, req, res, _next) {
  if (err instanceof ApiError) {
    if (err.status >= 500) console.error(`[${err.code}]`, err.message, err.extra);
    return res.status(err.status).json(err.toJSON());
  }

  // Multer's own errors arrive with a code but no status.
  if (err?.code === 'LIMIT_FILE_SIZE') {
    return res
      .status(413)
      .json(ApiError.payloadTooLarge('That file is too large').toJSON());
  }
  if (err?.code === 'LIMIT_FILE_COUNT' || err?.code === 'LIMIT_UNEXPECTED_FILE') {
    return res
      .status(400)
      .json(ApiError.badRequest('Too many files in one request').toJSON());
  }

  console.error('[unhandled]', err);
  return res.status(500).json({
    error: { code: 'internal_error', message: 'Something went wrong' },
  });
}
