import { config } from '../config.js';
import { ApiError } from '../errors.js';

/**
 * The only thing in the system allowed to talk to Stirling-PDF.
 *
 * Files arrive here as Buffers from multer's memory storage and leave as a
 * multipart body. Nothing touches disk: no temp file, no cache directory, no
 * bucket. The buffer's whole life is this request, and it is garbage once the
 * response is written.
 */
export async function runConversion({ tool, files, fields, onAbort }) {
  const url = `${config.stirling.baseUrl}${tool.endpoint}`;

  const form = new FormData();
  // Most endpoints take every upload as fileInput; a few name their slots
  // (overlay-pdfs: fileInput + overlayFiles, add-image: fileInput + imageFile).
  // tool.fileFields[i] names file i; extra files repeat the last entry.
  const fieldNames = tool.fileFields ?? [];
  files.forEach((file, index) => {
    form.append(
      fieldNames[index] ?? (fieldNames.length ? fieldNames[fieldNames.length - 1] : 'fileInput'),
      new Blob([file.buffer], { type: file.mimetype || 'application/octet-stream' }),
      file.originalname,
    );
  });
  for (const [key, value] of Object.entries(fields)) {
    if (value !== undefined && value !== null) form.append(key, String(value));
  }

  const controller = new AbortController();
  // Tracked separately from the signal: aborting with a reason makes fetch
  // reject with that reason rather than a DOMException named AbortError, so
  // sniffing err.name would misreport a timeout as an unreachable engine.
  let abortCause = null;

  const timer = setTimeout(() => {
    abortCause = 'timeout';
    controller.abort();
  }, config.stirling.timeoutMs);

  // If the phone drops the connection mid-conversion, stop paying for the
  // upstream work too.
  onAbort?.(() => {
    abortCause ??= 'client-disconnected';
    controller.abort();
  });

  const headers = {};
  if (config.stirling.apiKey) headers['X-API-KEY'] = config.stirling.apiKey;

  let response;
  try {
    response = await fetch(url, {
      method: 'POST',
      body: form,
      headers,
      signal: controller.signal,
    });
  } catch (err) {
    if (abortCause === 'timeout') {
      throw ApiError.timeout();
    }
    if (abortCause === 'client-disconnected') {
      // Nobody is listening for this; the route only needs it to refund.
      throw new ApiError(499, 'client_closed_request', 'The client disconnected');
    }
    throw ApiError.upstream(
      'Could not reach the conversion engine',
      config.nodeEnv === 'development' ? { cause: err?.message } : {},
    );
  } finally {
    // Headers are in. The body may still be streaming, and a slow download
    // shouldn't count against the conversion timeout.
    clearTimeout(timer);
  }

  if (!response.ok) {
    // Stirling puts a readable reason in the body; keep a slice of it for the
    // log but never forward it wholesale — it can echo file contents.
    const detail = await response.text().catch(() => '');
    console.error(
      `[stirling] ${response.status} ${tool.endpoint}: ${detail.slice(0, 500)}`,
    );

    if (response.status === 401 || response.status === 403) {
      throw ApiError.upstream('The conversion engine rejected this request');
    }
    if (response.status === 415) {
      throw ApiError.badRequest('The engine cannot read that file format');
    }
    throw ApiError.upstream('The file could not be converted');
  }

  // 204 is Stirling's "I ran, and there was nothing to produce" — the CSV
  // extractor answers this for any PDF with no detectable table. It is a
  // success status, so response.ok is true and it would otherwise stream a
  // zero-byte file straight to the user's phone.
  if (response.status === 204) {
    throw new ApiError(
      422,
      'nothing_extracted',
      'The engine found nothing to extract from that file',
    );
  }

  if (!response.body) {
    throw ApiError.upstream('The conversion engine returned an empty response');
  }

  // Stirling answers application/octet-stream for docx and zip outputs. That
  // is useless to the client, which decides how to save the file from this
  // header, so fall back to the registry's declared type. Only a specific
  // upstream type is allowed to win.
  const upstreamType = (response.headers.get('content-type') || '')
    .split(';')[0]
    .trim();
  const generic =
    !upstreamType ||
    upstreamType === 'application/octet-stream' ||
    upstreamType === 'application/x-www-form-urlencoded';

  return {
    body: response.body,
    contentType: generic ? tool.contentType : upstreamType,
    contentLength: response.headers.get('content-length'),
    // Forwards Stirling's own filename (e.g. auto-rename's detected title) so
    // the route can use it when the registry has no outputName of its own.
    disposition: response.headers.get('content-disposition') || null,
  };
}

/** Liveness probe for /readyz, so a bad STIRLING_BASE_URL surfaces early. */
export async function pingStirling() {
  try {
    const res = await fetch(`${config.stirling.baseUrl}/api/v1/info/status`, {
      signal: AbortSignal.timeout(4000),
    });
    return res.ok;
  } catch {
    return false;
  }
}
