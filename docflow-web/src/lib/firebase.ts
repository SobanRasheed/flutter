/**
 * Firebase web client — the same Firebase project the DocFlow mobile app uses
 * (docflow-5e0f8). The API key comes from the app's google-services.json and
 * was verified to accept Identity Toolkit calls from web origins.
 *
 * The backend only trusts this project's ID tokens, so web and mobile users
 * share accounts and conversion quota.
 */
import { initializeApp, getApps, getApp, type FirebaseApp } from 'firebase/app';
import {
  getAuth,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  signInWithPopup,
  GoogleAuthProvider,
  signOut,
  sendPasswordResetEmail,
  type Auth,
  type User,
} from 'firebase/auth';

export const firebaseConfig = {
  apiKey: 'AIzaSyCUf5jPx4C8cnmclbj9-r4QSCYmuOytTBE',
  authDomain: 'docflow-5e0f8.firebaseapp.com',
  projectId: 'docflow-5e0f8',
  storageBucket: 'docflow-5e0f8.firebasestorage.app',
  messagingSenderId: '709844626901',
};

export function fbApp(): FirebaseApp {
  return getApps().length ? getApp() : initializeApp(firebaseConfig);
}

export function fbAuth(): Auth {
  return getAuth(fbApp());
}

export type AuthUser = User;

export function watchAuth(cb: (user: AuthUser | null) => void): () => void {
  return onAuthStateChanged(fbAuth(), cb);
}

export async function loginEmail(email: string, password: string): Promise<User> {
  const cred = await signInWithEmailAndPassword(fbAuth(), email, password);
  return cred.user;
}

export async function signupEmail(
  email: string,
  password: string,
  displayName?: string,
): Promise<User> {
  const cred = await createUserWithEmailAndPassword(fbAuth(), email, password);
  if (displayName) await cred.user.updateProfile({ displayName });
  return cred.user;
}

export async function loginGoogle(): Promise<User> {
  const provider = new GoogleAuthProvider();
  const cred = await signInWithPopup(fbAuth(), provider);
  return cred.user;
}

export async function requestPasswordReset(email: string): Promise<void> {
  await sendPasswordResetEmail(fbAuth(), email);
}

export async function logout(): Promise<void> {
  await signOut(fbAuth());
}

/** Short, safe display label for the header chip. */
export function userLabel(user: User | null): string {
  if (!user) return '';
  return user.displayName || user.email || 'Account';
}

export function friendlyAuthError(err: unknown): string {
  const code = (err as { code?: string })?.code || '';
  const map: Record<string, string> = {
    'auth/invalid-email': 'That email address does not look right.',
    'auth/user-not-found': 'No account found with that email.',
    'auth/wrong-password': 'Incorrect email or password.',
    'auth/invalid-credential': 'Incorrect email or password.',
    'auth/invalid-login-credentials': 'Incorrect email or password.',
    'auth/too-many-requests': 'Too many attempts. Please wait a moment and try again.',
    'auth/email-already-in-use': 'An account with that email already exists. Try logging in.',
    'auth/weak-password': 'Password should be at least 6 characters.',
    'auth/popup-closed-by-user': 'Google sign-in was cancelled.',
    'auth/popup-blocked': 'Your browser blocked the sign-in popup. Allow popups and retry.',
    'auth/unauthorized-domain':
      'This domain is not yet authorized in Firebase. Add it under Authentication → Settings → Authorized domains.',
    'auth/operation-not-allowed':
      'This sign-in method is disabled in the Firebase console.',
  };
  return map[code] || (err as Error)?.message || 'Something went wrong. Please try again.';
}
