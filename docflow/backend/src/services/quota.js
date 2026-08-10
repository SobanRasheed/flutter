import { db, FieldValue, Timestamp } from '../firebase.js';
import { config } from '../config.js';
import { ApiError } from '../errors.js';

const USERS = 'users';

/**
 * The billing period is the calendar month in UTC. Storing it as "2026-08"
 * rather than a rolling 30-day window means the reset is trivially comparable
 * and can't drift as a user converts.
 */
export function currentPeriod(now = new Date()) {
  const month = String(now.getUTCMonth() + 1).padStart(2, '0');
  return `${now.getUTCFullYear()}-${month}`;
}

function shape(uid, data) {
  const limit = config.quota.freeMonthlyLimit;
  const isPro = data?.isPro === true;
  const used = data?.conversionsUsed ?? 0;

  return {
    uid,
    isPro,
    conversionsUsed: used,
    limit: isPro ? null : limit,
    remaining: isPro ? null : Math.max(0, limit - used),
    period: data?.period ?? currentPeriod(),
    lastResetDate: data?.lastResetDate?.toDate?.()?.toISOString() ?? null,
  };
}

/**
 * Reads the caller's quota, creating the document on first sight.
 *
 * Read-only: this never consumes a conversion, so the Flutter app can call it
 * freely to paint the "83 of 100 used" bar.
 */
export async function getQuota(uid) {
  const ref = db.collection(USERS).doc(uid);
  const snap = await ref.get();

  if (!snap.exists) {
    const seed = {
      conversionsUsed: 0,
      isPro: false,
      period: currentPeriod(),
      lastResetDate: FieldValue.serverTimestamp(),
      createdAt: FieldValue.serverTimestamp(),
    };
    await ref.set(seed);
    return shape(uid, { ...seed, lastResetDate: Timestamp.now() });
  }

  const data = snap.data();

  // A stale period means the month rolled over since their last conversion.
  // Report it as zero here; the reset is actually written by consumeQuota, so
  // a read never has to take a write lock.
  if (data.period !== currentPeriod()) {
    return shape(uid, { ...data, conversionsUsed: 0, period: currentPeriod() });
  }

  return shape(uid, data);
}

/**
 * Reserves one conversion inside a transaction, before any work happens.
 *
 * Reserving up front — rather than incrementing after Stirling succeeds — is
 * what makes the limit hold under concurrency. Two devices firing at once both
 * read 99, and without the transaction both would proceed to 101. The trade is
 * that a failed conversion must be refunded, which is what releaseQuota does.
 *
 * Throws ApiError.quotaExceeded (HTTP 402) at the cap. That status is the
 * paywall trigger, so it must not be swallowed or remapped.
 */
export async function consumeQuota(uid) {
  const ref = db.collection(USERS).doc(uid);
  const limit = config.quota.freeMonthlyLimit;
  const period = currentPeriod();

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);

    if (!snap.exists) {
      tx.set(ref, {
        conversionsUsed: 1,
        isPro: false,
        period,
        lastResetDate: FieldValue.serverTimestamp(),
        createdAt: FieldValue.serverTimestamp(),
      });
      return { uid, isPro: false, conversionsUsed: 1, limit, remaining: limit - 1 };
    }

    const data = snap.data();
    const isPro = data.isPro === true;

    // New month: the counter starts over and we stamp the reset.
    const rolledOver = data.period !== period;
    const used = rolledOver ? 0 : (data.conversionsUsed ?? 0);

    if (!isPro && used >= limit) {
      throw ApiError.quotaExceeded(used, limit);
    }

    tx.update(ref, {
      conversionsUsed: used + 1,
      period,
      ...(rolledOver ? { lastResetDate: FieldValue.serverTimestamp() } : {}),
    });

    return {
      uid,
      isPro,
      conversionsUsed: used + 1,
      limit: isPro ? null : limit,
      remaining: isPro ? null : Math.max(0, limit - (used + 1)),
    };
  });
}

/**
 * Gives a reserved conversion back after a failure.
 *
 * Best-effort by design: if the refund itself fails we log and move on rather
 * than turning a conversion error into a 500. Over-charging one credit is a
 * far smaller problem than losing the real error.
 */
export async function releaseQuota(uid) {
  try {
    const ref = db.collection(USERS).doc(uid);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const data = snap.data();
      // Don't refund across a month boundary — the credit belonged to the old
      // period and the counter has already been reset.
      if (data.period !== currentPeriod()) return;
      const used = data.conversionsUsed ?? 0;
      if (used <= 0) return;
      tx.update(ref, { conversionsUsed: used - 1 });
    });
  } catch (err) {
    console.error('[quota] refund failed for', uid, err?.message);
  }
}

/**
 * Flips Pro on or off. Deliberately not exposed on any client-facing route —
 * call it from your billing webhook (RevenueCat, Stripe, Play/App Store
 * notifications) once payment is verified.
 */
export async function setProStatus(uid, isPro) {
  await db
    .collection(USERS)
    .doc(uid)
    .set(
      { isPro: Boolean(isPro), proUpdatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
  return getQuota(uid);
}
