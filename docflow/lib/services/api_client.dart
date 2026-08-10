import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../models/quota.dart';
import 'api_exceptions.dart';
import 'auth_service.dart';

/// The result of a successful conversion: the bytes, plus the quota state the
/// backend reported alongside them.
///
/// The quota arrives in response headers, so the UI can update its counter
/// without a second round trip.
class ConversionResult {
  const ConversionResult({
    required this.bytes,
    required this.filename,
    required this.contentType,
    this.quota,
  });

  final Uint8List bytes;

  /// The name the backend chose, honouring the extension the output actually
  /// has — `split-pdf` returns a .zip, `pdf-to-word` a .docx.
  final String filename;
  final String contentType;
  final Quota? quota;
}

/// Talks to the DocFlow Node.js backend.
///
/// Every call carries a Firebase ID Token; the backend derives the user from
/// that signature and never from anything this client sends in the body. The
/// app has no route to Stirling-PDF and no way to write its own quota — both
/// are deliberate, and are what make the 100-conversion cap enforceable.
class ApiClient {
  ApiClient({AuthService? auth, http.Client? client})
      : _auth = auth ?? AuthService(),
        _client = client ?? http.Client();

  final AuthService _auth;
  final http.Client _client;

  void dispose() => _client.close();

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Fetches the token, refreshing it if Firebase says it is close to expiry.
  Future<String> _token({bool forceRefresh = false}) async {
    final token = await _auth.getIdToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw const AuthException('You need to sign in to convert files');
    }
    return token;
  }

  /// Reads the user's allowance. Cheap and safe to call on screen open —
  /// it never consumes a conversion.
  Future<Quota> fetchQuota() async {
    try {
      final response = await _client
          .get(
            _uri('/api/quota'),
            headers: {'Authorization': 'Bearer ${await _token()}'},
          )
          .timeout(ApiConfig.readTimeout);

      if (response.statusCode == 200) {
        return Quota.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      throw _decodeError(response.statusCode, response.body);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const ServerException('The server took too long', isTimeout: true);
    }
  }

  /// Uploads [files], runs [toolId] on them, and returns the converted bytes.
  ///
  /// Throws [QuotaExceededException] on HTTP 402 — the caller must treat that
  /// as "show the paywall", not as a failure to report.
  ///
  /// [options] carries per-tool parameters the backend validates: `password`
  /// for protect, `pages` for split, `level` for compress, `text` for
  /// watermark. Sending an unknown key is harmless; omitting a required one
  /// comes back as a [RequestException].
  Future<ConversionResult> convert({
    required String toolId,
    required List<File> files,
    Map<String, String> options = const {},
  }) async {
    try {
      return await _attemptConvert(
        toolId: toolId,
        files: files,
        options: options,
        forceRefresh: false,
      );
    } on AuthException catch (e) {
      // One retry with a forced token refresh. Firebase caches ID tokens for
      // an hour, and a token that expired while the app sat backgrounded is
      // the single most common 401 — worth recovering silently rather than
      // bouncing the user to the sign-in screen.
      if (!e.needsReauth) rethrow;
      return _attemptConvert(
        toolId: toolId,
        files: files,
        options: options,
        forceRefresh: true,
      );
    }
  }

  Future<ConversionResult> _attemptConvert({
    required String toolId,
    required List<File> files,
    required Map<String, String> options,
    required bool forceRefresh,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/convert/$toolId'))
      ..headers['Authorization'] = 'Bearer ${await _token(
        forceRefresh: forceRefresh,
      )}';

    for (final file in files) {
      if (!await file.exists()) {
        throw RequestException('"${_basename(file.path)}" could not be read');
      }
      // The field name must be "files" — it is what multer is configured to
      // accept on the backend.
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }
    request.fields.addAll(options);

    late final http.StreamedResponse streamed;
    try {
      streamed = await _client
          .send(request)
          .timeout(ApiConfig.conversionTimeout);
    } on SocketException {
      throw const NetworkException();
    } on TimeoutException {
      throw const ServerException(
        'The conversion took too long. Try a smaller file.',
        isTimeout: true,
      );
    }

    if (streamed.statusCode != 200) {
      // Errors are small JSON bodies; only success streams binary.
      throw _decodeError(streamed.statusCode, await streamed.stream.bytesToString());
    }

    final bytes = await streamed.stream.toBytes();
    if (bytes.isEmpty) {
      throw const ServerException('The server returned an empty file');
    }

    return ConversionResult(
      bytes: bytes,
      filename: _filenameFrom(streamed.headers) ?? 'converted',
      contentType:
          streamed.headers['content-type'] ?? 'application/octet-stream',
      quota: _quotaFrom(streamed.headers),
    );
  }

  /// Reads the quota the backend attached to a successful conversion.
  Quota? _quotaFrom(Map<String, String> headers) {
    final used = int.tryParse(headers['x-conversions-used'] ?? '');
    if (used == null) return null;
    final remaining = int.tryParse(headers['x-conversions-remaining'] ?? '');
    final isPro = headers['x-is-pro'] == 'true';
    return Quota(
      conversionsUsed: used,
      isPro: isPro,
      // The backend sends -1 for Pro, which has no meaningful remainder.
      remaining: isPro || remaining == null || remaining < 0 ? null : remaining,
      limit: isPro ? null : (remaining != null ? used + remaining : null),
    );
  }

  String? _filenameFrom(Map<String, String> headers) {
    final disposition = headers['content-disposition'];
    if (disposition == null) return null;
    final match = RegExp('filename="?([^";]+)"?').firstMatch(disposition);
    return match?.group(1);
  }

  String _basename(String path) => path.split(RegExp(r'[/\\]')).last;

  /// Turns the backend's `{ error: { code, message } }` envelope into the
  /// matching typed exception. Falls back on status alone when the body is
  /// not the expected shape — a proxy or gateway can answer without it.
  ApiException _decodeError(int status, String body) {
    Map<String, dynamic>? error;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
        error = (decoded['error'] as Map).cast<String, dynamic>();
      }
    } catch (_) {
      // Not JSON. Status code alone still tells us enough.
    }

    final code = error?['code'] as String?;
    final message = error?['message'] as String?;

    if (status == 402) {
      return QuotaExceededException(
        message: message ??
            'You have used all your free conversions this month.',
        conversionsUsed: (error?['conversionsUsed'] as num?)?.toInt() ?? 0,
        limit: (error?['limit'] as num?)?.toInt() ?? 100,
      );
    }

    return switch (status) {
      401 => AuthException(message ?? 'Your session expired. Sign in again.'),
      403 => const AuthException('You do not have access to this'),
      400 || 415 => RequestException(
          message ?? 'That file cannot be converted',
          code: code,
        ),
      413 => const RequestException('That file is too large'),
      422 => RequestException(
          message ?? 'Nothing could be extracted from that file',
          code: code ?? 'nothing_extracted',
        ),
      429 => const ServerException('Too many requests. Try again in a moment.'),
      504 => const ServerException(
          'The conversion took too long. Try a smaller file.',
          isTimeout: true,
        ),
      _ => ServerException(message ?? 'Conversion failed. Please try again.'),
    };
  }
}
