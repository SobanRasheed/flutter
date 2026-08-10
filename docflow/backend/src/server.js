import 'dotenv/config';

import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';

import { assertConfig, config } from './config.js';
import { errorHandler } from './errors.js';
import { requireAuth } from './middleware/auth.js';
import convertRouter from './routes/convert.js';
import { pingStirling } from './services/stirling.js';

assertConfig();

const app = express();

// Behind Azure Container Apps' ingress, so req.ip is the client's, not the
// proxy's. express-rate-limit refuses to run without this being set.
app.set('trust proxy', 1);
app.disable('x-powered-by');

app.use(helmet());
app.use(
  cors({
    origin: config.corsOrigins.length ? config.corsOrigins : false,
    credentials: false,
  }),
);

// JSON body parsing for the small routes. Multipart never reaches this — the
// convert route's multer runs first and consumes the stream itself.
app.use(express.json({ limit: '64kb' }));

/**
 * Rate limited per Firebase uid, falling back to IP for unauthenticated hits.
 * Keying on the uid is what stops one account from burning the container's
 * memory with parallel uploads; keying on IP alone would punish everyone
 * behind a carrier NAT.
 */
app.use(
  '/api',
  rateLimit({
    windowMs: 60_000,
    limit: config.rateLimitPerMinute,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    keyGenerator: (req) => req.user?.uid || req.ip,
    message: {
      error: {
        code: 'rate_limited',
        message: 'Too many requests. Slow down and try again shortly.',
      },
    },
  }),
);

/**
 * Liveness and readiness. Azure polls this; keep it unauthenticated and cheap.
 * The Stirling ping is only run when asked for, so the probe does not depend
 * on a second service being up.
 */
app.get('/healthz', (req, res) => {
  res.json({ status: 'ok', env: config.nodeEnv });
});

app.get('/readyz', async (req, res) => {
  const engine = await pingStirling();
  res.status(engine ? 200 : 503).json({
    status: engine ? 'ready' : 'degraded',
    stirling: engine ? 'up' : 'unreachable',
  });
});

/** Echoes back what the token proved, useful when wiring up the Flutter side. */
app.get('/api/me', requireAuth, (req, res) => {
  res.json({ user: req.user });
});

app.use('/api', convertRouter);

app.use((req, res) => {
  res.status(404).json({
    error: { code: 'not_found', message: `No route for ${req.method} ${req.path}` },
  });
});

app.use(errorHandler);

const server = app.listen(config.port, () => {
  console.log(
    `DocFlow backend listening on :${config.port} (${config.nodeEnv})\n` +
      `  engine        ${config.stirling.baseUrl}\n` +
      `  free limit    ${config.quota.freeMonthlyLimit}/month\n` +
      `  max upload    ${(config.upload.maxBytes / 1024 / 1024).toFixed(0)} MB`,
  );
});

// Container platforms send SIGTERM and then kill. Finish in-flight conversions
// rather than truncating someone's download.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    console.log(`${signal} received, draining...`);
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 30_000).unref();
  });
}

export default app;
