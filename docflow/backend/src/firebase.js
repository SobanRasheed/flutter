import admin from 'firebase-admin';

/**
 * Boots the Firebase Admin SDK exactly once.
 *
 * Credentials come from the environment, never from a file in the image. On
 * Azure Container Apps set FIREBASE_SERVICE_ACCOUNT_B64 as a secret; base64
 * keeps the private key's newlines intact through secret stores that would
 * otherwise mangle them.
 */
function loadServiceAccount() {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT_B64;
  if (b64) {
    return JSON.parse(Buffer.from(b64, 'base64').toString('utf8'));
  }

  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (raw) {
    const parsed = JSON.parse(raw);
    // Some secret stores collapse the real newlines in the PEM to the literal
    // two characters \n. Put them back or the SDK rejects the key.
    if (parsed.private_key) {
      parsed.private_key = parsed.private_key.replace(/\\n/g, '\n');
    }
    return parsed;
  }

  return null;
}

if (!admin.apps.length) {
  const serviceAccount = loadServiceAccount();

  admin.initializeApp({
    credential: serviceAccount
      ? admin.credential.cert(serviceAccount)
      : admin.credential.applicationDefault(),
    projectId:
      process.env.FIREBASE_PROJECT_ID || serviceAccount?.project_id || undefined,
  });
}

export const auth = admin.auth();
export const db = admin.firestore();
export const FieldValue = admin.firestore.FieldValue;
export const Timestamp = admin.firestore.Timestamp;
export default admin;
