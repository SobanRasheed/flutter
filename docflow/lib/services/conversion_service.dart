import 'dart:io';

import '../models/quota.dart';
import 'api_client.dart';
import 'api_exceptions.dart';
import 'file_store.dart';

/// What a conversion attempt produced.
///
/// Deliberately a sealed union rather than a nullable result plus an error
/// string: [ConversionQuotaBlocked] is not a failure to report in a snackbar,
/// it is a distinct outcome that must open the paywall. Making it a separate
/// case means a caller cannot forget to handle it.
sealed class ConversionOutcome {
  const ConversionOutcome();
}

/// The file converted, saved to disk, and was logged in SQLite.
class ConversionSuccess extends ConversionOutcome {
  const ConversionSuccess({required this.file, this.quota});

  final StoredFile file;

  /// Quota as of this conversion, when the backend reported it.
  final Quota? quota;
}

/// The backend answered 402. Show the paywall — do not report an error.
class ConversionQuotaBlocked extends ConversionOutcome {
  const ConversionQuotaBlocked({required this.quota, required this.message});

  final Quota quota;
  final String message;
}

/// Something went wrong and the user should be told.
class ConversionFailure extends ConversionOutcome {
  const ConversionFailure({
    required this.message,
    this.needsReauth = false,
    this.isRetryable = false,
  });

  final String message;

  /// The session is gone; the user has to sign in again.
  final bool needsReauth;

  /// Worth offering a "Try again" button — network blips and timeouts.
  final bool isRetryable;
}

/// Runs a conversion end to end: upload, receive, save, log.
///
/// The pipeline is exactly the architecture's step 3 through 6 — the file goes
/// to Node, Node holds it in RAM and forwards it to Stirling, the bytes come
/// back, and only then does anything touch this device's disk. Nothing is
/// written locally until the conversion actually succeeded, so a failed attempt
/// leaves no half-file in the library.
class ConversionService {
  ConversionService({ApiClient? api, FileStore? store})
      : _api = api ?? ApiClient(),
        _store = store ?? FileStore.instance;

  final ApiClient _api;
  final FileStore _store;

  void dispose() => _api.dispose();

  /// Converts [files] with [toolId] and stores the result.
  ///
  /// [options] are the per-tool parameters the backend validates — `password`,
  /// `pages`, `level`, `text`. [outputName] overrides the name the backend
  /// chose, for flows where the user typed one.
  Future<ConversionOutcome> run({
    required String toolId,
    required List<File> files,
    Map<String, String> options = const {},
    String? outputName,
  }) async {
    if (files.isEmpty) {
      return const ConversionFailure(message: 'Pick a file to convert');
    }

    try {
      final result = await _api.convert(
        toolId: toolId,
        files: files,
        options: options,
      );

      // Keep the extension the backend actually produced. A user-typed name
      // like "Report" must not turn a .zip into an extensionless blob, and
      // split-pdf/pdf-to-image both return zips regardless of the input.
      final filename = outputName == null
          ? result.filename
          : _withExtensionOf(outputName, result.filename);

      final stored = await _store.save(
        bytes: result.bytes,
        filename: filename,
        toolId: toolId,
        sourceName: files.length == 1 ? _basename(files.first.path) : null,
      );

      return ConversionSuccess(file: stored, quota: result.quota);
    } on QuotaExceededException catch (e) {
      return ConversionQuotaBlocked(
        quota: Quota(
          conversionsUsed: e.conversionsUsed,
          isPro: false,
          limit: e.limit,
          remaining: 0,
        ),
        message: e.message,
      );
    } on AuthException catch (e) {
      return ConversionFailure(
        message: e.message,
        needsReauth: e.needsReauth,
      );
    } on NetworkException catch (e) {
      return ConversionFailure(message: e.message, isRetryable: true);
    } on ServerException catch (e) {
      return ConversionFailure(message: e.message, isRetryable: true);
    } on RequestException catch (e) {
      // A bad request will fail again identically — no retry offered.
      return ConversionFailure(message: e.message);
    } on FileSystemException {
      return const ConversionFailure(
        message: 'The file could not be saved. Check your storage space.',
      );
    }
  }

  /// Reads the allowance without spending any of it.
  ///
  /// Returns null when it cannot be read; callers show nothing rather than a
  /// wrong number. A stale quota badge is worse than no badge.
  Future<Quota?> quota() async {
    try {
      return await _api.fetchQuota();
    } on ApiException {
      return null;
    }
  }

  /// Borrows [source]'s extension when [name] has none of its own.
  String _withExtensionOf(String name, String source) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return source;
    if (trimmed.contains('.')) return trimmed;

    final dot = source.lastIndexOf('.');
    return dot == -1 ? trimmed : '$trimmed${source.substring(dot)}';
  }

  String _basename(String path) => path.split(RegExp(r'[/\\]')).last;
}
