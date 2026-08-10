import '../models/quota.dart';

/// Base for every failure the API layer surfaces.
///
/// Screens should switch on the subtype rather than parsing [message]: the
/// type is the contract, the message is what gets shown to the user.
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// HTTP 402. The one case that is not an error at all — it means the user hit
/// the free cap and should see the paywall, not a red snackbar.
class QuotaExceededException extends ApiException {
  const QuotaExceededException({
    required String message,
    required this.conversionsUsed,
    required this.limit,
  }) : super(message);

  final int conversionsUsed;
  final int limit;

  Quota get quota => Quota(
        conversionsUsed: conversionsUsed,
        isPro: false,
        limit: limit,
        remaining: 0,
      );
}

/// 401. The token was missing, expired past refresh, or revoked. The user has
/// to sign in again — retrying the same call will not help.
class AuthException extends ApiException {
  const AuthException(super.message, {this.needsReauth = true});

  final bool needsReauth;
}

/// 400 / 413 / 422. The request itself was wrong: unsupported format, file too
/// large, nothing extractable. Retrying unchanged will fail identically, so
/// the UI should explain rather than offer a retry button.
class RequestException extends ApiException {
  const RequestException(super.message, {this.code});

  final String? code;

  /// The backend's 422 for a conversion that ran but produced nothing.
  bool get isEmptyResult => code == 'nothing_extracted';
}

/// 5xx, timeouts, and socket failures. Transient by nature — offer a retry.
class ServerException extends ApiException {
  const ServerException(super.message, {this.isTimeout = false});

  final bool isTimeout;
}

/// No usable connection at all. Distinct from [ServerException] so the UI can
/// say "you're offline" instead of blaming the service.
class NetworkException extends ApiException {
  const NetworkException([super.message = 'No internet connection']);
}
