import { auth } from '../firebase.js';
import { ApiError } from '../errors.js';

/**
 * Verifies the Firebase ID Token on every protected route.
 *
 * The client is untrusted. Nothing downstream may read a uid from the request
 * body or a query string — the only uid that exists is the one the Admin SDK
 * extracted from a signature it verified itself.
 *
 * `checkRevoked` is on, so a signed-out or disabled account stops working
 * immediately instead of coasting on an hour-long token.
 */
export async function requireAuth(req, res, next) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');

  if (scheme?.toLowerCase() !== 'bearer' || !token) {
    return next(
      ApiError.unauthorized('Expected an "Authorization: Bearer <idToken>" header'),
    );
  }

  try {
    const decoded = await auth.verifyIdToken(token, true);
    req.user = {
      uid: decoded.uid,
      email: decoded.email ?? null,
      name: decoded.name ?? null,
      provider: decoded.firebase?.sign_in_provider ?? null,
    };
    return next();
  } catch (err) {
    const expired = err?.code === 'auth/id-token-expired';
    const revoked = err?.code === 'auth/id-token-revoked';
    return next(
      new ApiError(
        401,
        expired ? 'token_expired' : revoked ? 'token_revoked' : 'unauthenticated',
        expired
          ? 'Your session expired. Refresh the ID token and retry.'
          : revoked
            ? 'This session was revoked. Sign in again.'
            : 'Could not verify that ID token',
      ),
    );
  }
}
