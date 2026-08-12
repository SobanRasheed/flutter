import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Handles Firebase Authentication with Google Sign-In.
///
/// Exposes the Firebase ID Token so the Flutter app can send it
/// to the Node.js backend on Azure for verification.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// google_sign_in 6.x is instance-based — `GoogleSignIn.instance` and
  /// `authenticate()` belong to the 7.x API and do not exist here.
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of auth state changes — use with StreamBuilder for reactive UI.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  /// Whether a user is currently signed in.
  bool get isSignedIn => _auth.currentUser != null;

  /// Get the Firebase ID Token to send to the Node.js backend.
  ///
  /// The backend verifies this token using Admin SDK's `verifyIdToken()`.
  /// Returns null if no user is signed in.
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    return await _auth.currentUser?.getIdToken(forceRefresh);
  }

  /// Sign in with Google.
  ///
  /// On mobile, uses `google_sign_in` plugin.
  /// On web, uses Firebase popup to avoid DWDS hang issues.
  ///
  /// Returns the [UserCredential] on success, or null if the user
  /// cancelled the flow.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: use Firebase popup (avoids DWDS hang / client ID issues)
        final provider = GoogleAuthProvider();
        return await _auth.signInWithPopup(provider);
      } else {
        // Mobile: use google_sign_in plugin
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User cancelled

        final googleAuth = await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } catch (e) {
      debugPrint('Error during Google Sign-In: $e');
      rethrow;
    }
  }

  /// Sign in with email and password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Create a new account with email and password.
  Future<UserCredential> createUserWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }


  /// Sends a Firebase password-reset email to [email].
  ///
  /// Firebase delivers a secure link directly to the inbox. The user taps the
  /// link, enters a new password, and is signed back in — no OTP code needed
  /// on our side.
  ///
  /// Throws [FirebaseAuthException] on invalid address or network errors.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign out from both Google and Firebase.
  ///
  /// On web, skips Google sign-out to avoid crash from uninitialised
  /// GoogleSignIn context.
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }
}
