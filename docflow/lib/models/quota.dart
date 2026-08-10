/// The user's conversion allowance, as reported by the backend.
///
/// This is a mirror, never a source of truth. The backend decides whether a
/// conversion may proceed; these numbers exist so the UI can show a progress
/// bar and warn before the user picks a file. Never gate a request on this
/// locally — a stale copy would either block a legitimate conversion or let
/// the user reach the upload screen only to be refused.
class Quota {
  const Quota({
    required this.conversionsUsed,
    required this.isPro,
    this.limit,
    this.remaining,
  });

  final int conversionsUsed;
  final bool isPro;

  /// Null for Pro users, who have no cap.
  final int? limit;
  final int? remaining;

  factory Quota.fromJson(Map<String, dynamic> json) => Quota(
        conversionsUsed: (json['conversionsUsed'] as num?)?.toInt() ?? 0,
        isPro: json['isPro'] == true,
        limit: (json['limit'] as num?)?.toInt(),
        remaining: (json['remaining'] as num?)?.toInt(),
      );

  /// A fresh account that has not synced yet — shown while the first read is
  /// in flight so the account screen isn't blank.
  static const unknown = Quota(conversionsUsed: 0, isPro: false);

  bool get isExhausted => !isPro && (remaining ?? 1) <= 0;

  /// Worth nudging toward Pro, but not blocking.
  bool get isRunningLow => !isPro && (remaining ?? 100) <= 10;

  /// 0.0 to 1.0 for the account screen's bar. Pro reads as empty.
  double get fraction {
    if (isPro || limit == null || limit == 0) return 0;
    return (conversionsUsed / limit!).clamp(0.0, 1.0);
  }

  String get label {
    if (isPro) return 'Unlimited conversions';
    if (limit == null) return '$conversionsUsed conversions used';
    return '$conversionsUsed of $limit conversions used';
  }
}
