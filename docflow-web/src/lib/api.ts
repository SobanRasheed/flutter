/**
 * Client for the DocFlow backend running on the conversion VPS
 * (http://145.241.123.187:5000). The backend is the only thing allowed to
 * talk to the Stirling-PDF engine; the browser never learns a Stirling URL.
 *
 * Conversions use XHR (not fetch) so we can show real upload progress.
 */
import type { AuthUser } from './firebase';

export const API_BASE: string =
  import.meta.env.PUBLIC_API_BASE_URL || 'http://145.241.123.187:5000';

export interface Quota {
  conversionsUsed: number;
  limit: number | null;
  remaining: number | null;
  isPro: boolean;
}

export interface ConvertResult {
  blob: Blob;
  filename: string;
  contentType: string;
  quota: Quota | null;
}

export interface ConvertProgress {
  phase: 'uploading' | 'processing';
  /** 0..1, only meaningful while uploading. */
  fraction: number;
}

function normalizeQuota(payload: Record<string, unknown>): Quota {
  const isPro = Boolean(payload.isPro);
  const used = Number(payload.conversionsUsed ?? 0) || 0;
  const limit = payload.limit == null ? null : Number(payload.limit);
  const remaining = payload.remaining == null ? null : Number(payload.remaining);
  return { conversionsUsed: used, limit: isPro ? null : limit, remaining: isPro ? null : remaining, isPro };
}

export async function fetchQuota(user: AuthUser): Promise<Quota | null> {
  try {
    const token = await user.getIdToken();
    const res = await fetch(`${API_BASE}/api/quota`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!res.ok) return null;
    return normalizeQuota(await res.json());
  } catch {
    return null;
  }
}

interface ApiErrorEnvelope {
  error?: { code?: string; message?: string; conversionsUsed?: number; limit?: number };
}

export class ConversionError extends Error {
  status: number;
  code: string;
  /** Present on HTTP 402 — drives the paywall notice. */
  used: number | null;
  limit: number | null;

  constructor(status: number, code: string, message: string, used?: number, limit?: number) {
    super(message);
    this.status = status;
    this.code = code;
    this.used = used ?? null;
    this.limit = limit ?? null;
  }
}

function filenameFromDisposition(disposition: string | null): string | null {
  if (!disposition) return null;
  const m = /filename="?([^";]+)"?/.exec(disposition);
  return m?.[1] || null;
}

export function convert(opts: {
  toolId: string;
  files: File[];
  options: Record<string, string>;
  token: string;
  onProgress?: (p: ConvertProgress) => void;
}): Promise<ConvertResult> {
  const { toolId, files, options, token, onProgress } = opts;

  return new Promise((resolve, reject) => {
    const form = new FormData();
    // Field name must be "files" — what multer accepts on the backend.
    for (const file of files) form.append('files', file, file.name);
    for (const [key, value] of Object.entries(options)) {
      if (value !== '' && value !== undefined) form.append(key, value);
    }

    const xhr = new XMLHttpRequest();
    xhr.open('POST', `${API_BASE}/api/convert/${toolId}`);
    xhr.setRequestHeader('Authorization', `Bearer ${token}`);
    xhr.responseType = 'blob';

    xhr.upload.onprogress = (e) => {
      if (e.lengthComputable) {
        onProgress?.({ phase: 'uploading', fraction: e.loaded / e.total });
      }
    };
    xhr.upload.onload = () => onProgress?.({ phase: 'processing', fraction: 1 });

    xhr.onload = async () => {
      if (xhr.status === 200) {
        const blob = xhr.response as Blob;
        if (blob.size === 0) {
          reject(new ConversionError(502, 'empty_response', 'The server returned an empty file'));
          return;
        }
        // The quota headers may be hidden by CORS unless the backend exposes
        // them; fall back to the /api/quota shape when they are unreadable.
        const used = Number(xhr.getResponseHeader('X-Conversions-Used'));
        let quota: Quota | null = null;
        if (Number.isFinite(used) && xhr.getResponseHeader('X-Conversions-Used') !== null) {
          const remaining = Number(xhr.getResponseHeader('X-Conversions-Remaining'));
          const isPro = xhr.getResponseHeader('X-Is-Pro') === 'true';
          quota = {
            conversionsUsed: used,
            limit: isPro || !Number.isFinite(remaining) || remaining < 0 ? null : used + remaining,
            remaining: isPro || !Number.isFinite(remaining) || remaining < 0 ? null : remaining,
            isPro,
          };
        }
        resolve({
          blob,
          filename:
            filenameFromDisposition(xhr.getResponseHeader('Content-Disposition')) ||
            'converted',
          contentType: xhr.getResponseHeader('Content-Type') || 'application/octet-stream',
          quota,
        });
        return;
      }

      // Error bodies are JSON envelopes: { error: { code, message } }.
      let envelope: ApiErrorEnvelope = {};
      try {
        const text = await (xhr.response as Blob).text();
        envelope = JSON.parse(text) as ApiErrorEnvelope;
      } catch {
        /* not JSON — fall through to a status-based message */
      }
      const err = envelope.error || {};
      const messages: Record<number, string> = {
        400: 'That request was rejected. Check the file and options and try again.',
        401: 'Your session expired. Please sign in again.',
        402: 'You have used all your free conversions this month.',
        413: 'That file is too large. The limit is 50 MB per upload.',
        415: 'The engine cannot read that file format.',
        422: 'The engine found nothing to extract from that file.',
        429: 'Too many requests. Please wait a moment and try again.',
        504: 'The conversion took too long. Try a smaller file.',
      };
      reject(
        new ConversionError(
          xhr.status,
          err.code || 'conversion_failed',
          err.message || messages[xhr.status] || 'Conversion failed. Please try again.',
          err.conversionsUsed,
          err.limit,
        ),
      );
    };

    xhr.onerror = () =>
      reject(
        new ConversionError(
          0,
          'network_error',
          'Could not reach the DocFlow server. Check your connection and try again.',
        ),
      );

    xhr.send(form);
  });
}

export function formatBytes(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}
