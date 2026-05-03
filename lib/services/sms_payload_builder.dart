import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../data/values/values.dart';

/// SMS payload constants and contract.
///
/// MUST match `src/control_logic/sms_payload_handler.py` on the hub
/// byte-for-byte. Any drift here causes the hub to silently reject
/// payloads at the schema or HMAC verification stage.
///
/// Wire format (11 pipe-separated fields):
///   MED|<change_type>|<change_id>|<elder_id>|<drug_name>|<dosage>|
///   <time_due>|<days_of_week>|<active>|<timestamp>|HMAC=<hex>
class SmsPayload {
  static const String sentinel    = 'MED';
  static const String hmacPrefix  = 'HMAC=';
  static const String fieldDelim  = '|';

  /// Single-segment SMS limit. Payloads exceeding this are concatenated
  /// SMS — handled transparently by the OS messenger via url_launcher.
  static const int singleSegmentLimit = 160;

  SmsPayload._();
}

/// Builder for hub-compatible SMS payloads.
///
/// Produces strings byte-identical to what `SMSPayloadHandler._verify_hmac`
/// expects. Verified via cross-language test fixtures (see test/).
class SmsPayloadBuilder {
  /// HMAC key — the pairing-token-derived shared secret. The hub uses
  /// `config.pairing_token` directly as the HMAC key in its current
  /// implementation, so we mirror that here.
  final String hmacKey;

  const SmsPayloadBuilder({required this.hmacKey});

  /// Build a fully-signed INSERT payload for a new medication schedule.
  ///
  /// [changeId] defaults to a fresh UUIDv4. Pass an explicit value for
  /// idempotent retries — the same change_id will be rejected by the
  /// hub's duplicate-detection logic regardless of resend attempts.
  ///
  /// [timestamp] defaults to "now" in UTC ISO-8601 with millisecond
  /// precision and a 'Z' suffix — matching the hub's `_utcnow_iso()`
  /// format exactly. Override for deterministic tests.
  String buildInsert({
    required int elderId,
    required String drugName,
    required String dosage,
    required String timeDue,
    String daysOfWeek = 'DAILY',
    int active = 1,
    String? changeId,
    DateTime? timestamp,
  }) {
    return _build(
      changeType: ChangeType.insert,
      elderId: elderId,
      drugName: drugName,
      dosage: dosage,
      timeDue: timeDue,
      daysOfWeek: daysOfWeek,
      active: active,
      changeId: changeId,
      timestamp: timestamp,
    );
  }

  String buildUpdate({
    required int elderId,
    required String drugName,
    required String dosage,
    required String timeDue,
    String daysOfWeek = 'DAILY',
    int active = 1,
    String? changeId,
    DateTime? timestamp,
  }) {
    return _build(
      changeType: ChangeType.update,
      elderId: elderId,
      drugName: drugName,
      dosage: dosage,
      timeDue: timeDue,
      daysOfWeek: daysOfWeek,
      active: active,
      changeId: changeId,
      timestamp: timestamp,
    );
  }

  String buildDelete({
    required int elderId,
    required String drugName,
    required String dosage,
    required String timeDue,
    String daysOfWeek = 'DAILY',
    String? changeId,
    DateTime? timestamp,
  }) {
    return _build(
      changeType: ChangeType.delete,
      elderId: elderId,
      drugName: drugName,
      dosage: dosage,
      timeDue: timeDue,
      daysOfWeek: daysOfWeek,
      active: 0,
      changeId: changeId,
      timestamp: timestamp,
    );
  }

  // ──────────────────────────────────────────────────────────────────

  /// Validates inputs that would otherwise fail at the hub's parser.
  /// We catch them here for fast feedback in the UI.
  static String? validateField({
    required String drugName,
    required String dosage,
    required String timeDue,
  }) {
    if (drugName.contains(SmsPayload.fieldDelim)) {
      return 'Drug name cannot contain "|".';
    }
    if (dosage.contains(SmsPayload.fieldDelim)) {
      return 'Dosage cannot contain "|".';
    }
    if (!RegExp(r'^[0-2]\d:[0-5]\d$').hasMatch(timeDue)) {
      return 'Time must be HH:MM (24-hour).';
    }
    return null;
  }

  String _build({
    required String changeType,
    required int elderId,
    required String drugName,
    required String dosage,
    required String timeDue,
    required String daysOfWeek,
    required int active,
    String? changeId,
    DateTime? timestamp,
  }) {
    // Defensive — UI should have caught these via validateField, but
    // guard the wire format directly to prevent corrupt payloads.
    final validationError = validateField(
      drugName: drugName,
      dosage: dosage,
      timeDue: timeDue,
    );
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final cid = changeId ?? const Uuid().v4();
    final ts  = _formatUtcIso(timestamp ?? DateTime.now().toUtc());

    // Canonical bytes — exactly what the hub's _verify_hmac signs over.
    // All fields up to but NOT including HMAC=, joined with '|'.
    final canonical = [
      SmsPayload.sentinel,
      changeType,
      cid,
      elderId.toString(),
      drugName,
      dosage,
      timeDue,
      daysOfWeek,
      active.toString(),
      ts,
    ].join(SmsPayload.fieldDelim);

    final tag = _signHex(canonical);
    return '$canonical${SmsPayload.fieldDelim}${SmsPayload.hmacPrefix}$tag';
  }

  /// HMAC-SHA256 over UTF-8 bytes, hex-encoded lowercase.
  /// Mirrors hub's:
  ///   hmac.new(key.encode('utf-8'), canonical.encode('utf-8'),
  ///            hashlib.sha256).hexdigest()
  String _signHex(String canonical) {
    final keyBytes = utf8.encode(hmacKey);
    final msgBytes = utf8.encode(canonical);
    final digest = Hmac(sha256, keyBytes).convert(msgBytes);
    return digest.toString(); // already lowercase hex
  }

  /// Format DateTime as the hub's `_utcnow_iso()` does:
  ///   isoformat(timespec='milliseconds').replace('+00:00', 'Z')
  /// Example: 2026-04-28T09:30:00.000Z
  static String _formatUtcIso(DateTime t) {
    final utc = t.toUtc();
    final ms = utc.millisecond.toString().padLeft(3, '0');
    final base = utc.toIso8601String(); // e.g. '2026-04-28T09:30:00.000Z'
    // Dart's toIso8601String() already emits the right form for UTC,
    // but be defensive in case Dart-version variations omit the Z.
    if (base.endsWith('Z')) return base;
    if (base.contains('+')) return base.replaceAll(RegExp(r'\+\d{2}:\d{2}$'), 'Z');
    // Fallback explicit construction.
    final pad = (int n, int w) => n.toString().padLeft(w, '0');
    return '${pad(utc.year, 4)}-${pad(utc.month, 2)}-${pad(utc.day, 2)}'
        'T${pad(utc.hour, 2)}:${pad(utc.minute, 2)}:${pad(utc.second, 2)}'
        '.${ms}Z';
  }
}
