import { Router } from 'express';
import multer from 'multer';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';

import { config } from '../config.js';
import { ApiError, asyncRoute } from '../errors.js';
import { requireAuth } from '../middleware/auth.js';
import { consumeQuota, getQuota, releaseQuota } from '../services/quota.js';
import { assertAccepted, getTool, TOOLS } from '../services/tools.js';
import { runConversion } from '../services/stirling.js';

const router = Router();

/**
 * memoryStorage is the architectural requirement, not a convenience: the file
 * lives in this process's heap and nowhere else. Switching this to diskStorage
 * would silently start persisting user documents to the container filesystem.
 */
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: config.upload.maxBytes,
    files: config.upload.maxFiles,
  },
});

/** The tool catalogue, so the app can grey out anything the server dropped. */
router.get('/tools', (req, res) => {
  res.json({
    tools: Object.entries(TOOLS).map(([id, tool]) => ({
      id,
      accepts: tool.accepts,
      multiFile: Boolean(tool.multiFile),
      minFiles: tool.minFiles ?? 1,
      maxUploadBytes: config.upload.maxBytes,
    })),
  });
});

/**
 * Read-only quota check. The paywall can also be driven from here, before the
 * user picks a file — a nicer flow than letting them choose a document and
 * then refusing it.
 */
router.get(
  '/quota',
  requireAuth,
  asyncRoute(async (req, res) => {
    res.json(await getQuota(req.user.uid));
  }),
);

/**
 * The conversion route.
 *
 *   POST /api/convert/:toolId
 *   Authorization: Bearer <firebase id token>
 *   multipart/form-data: files[] + tool-specific fields
 *
 * Order matters and is deliberate:
 *   1. verify the token   — untrusted client, no uid from the body
 *   2. validate the input — a bad request must not cost a credit
 *   3. reserve the credit — transactional, so the cap holds under concurrency
 *   4. convert            — in RAM, forwarded to Stirling
 *   5. stream back        — refunding the credit if anything failed
 */
router.post(
  '/convert/:toolId',
  requireAuth,
  upload.array('files', config.upload.maxFiles),
  asyncRoute(async (req, res) => {
    const { toolId } = req.params;
    const { uid } = req.user;

    const tool = getTool(toolId);
    const files = req.files ?? [];
    if (files.length === 0) {
      throw ApiError.badRequest('No files were uploaded');
    }

    assertAccepted(tool, toolId, files);
    // Throws on bad parameters (missing password, empty page range, ...).
    const fields = tool.fields(req.body ?? {});

    // Reserve before the work. Throws 402 at the cap — the paywall trigger.
    const quota = await consumeQuota(uid);

    let refunded = false;
    const refund = async () => {
      if (refunded) return;
      refunded = true;
      await releaseQuota(uid);
    };

    let result;
    try {
      result = await runConversion({
        tool,
        files,
        fields,
        onAbort: (abort) => res.once('close', () => {
          if (!res.writableEnded) abort();
        }),
      });
    } catch (err) {
      await refund();
      throw err;
    }

    const filename = tool.outputName(files, req.body ?? {});
    res.setHeader('Content-Type', result.contentType);
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${filename.replace(/"/g, '')}"`,
    );
    if (result.contentLength) {
      res.setHeader('Content-Length', result.contentLength);
    }
    // Flutter reads these to update the quota bar without a second round trip.
    res.setHeader('X-Conversions-Used', String(quota.conversionsUsed));
    res.setHeader('X-Conversions-Remaining', String(quota.remaining ?? -1));
    res.setHeader('X-Is-Pro', String(quota.isPro));

    try {
      await pipeline(Readable.fromWeb(result.body), res);
    } catch (err) {
      // The bytes were already flowing, so the status line is gone and we
      // cannot turn this into a JSON error. Refund and let the socket close;
      // the client sees a truncated download and can retry.
      await refund();
      if (!res.writableEnded) res.destroy(err);
      console.error('[convert] stream failed for', uid, err?.message);
    }
  }),
);

export default router;
