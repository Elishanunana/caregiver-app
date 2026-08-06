import 'package:url_launcher/url_launcher.dart';

/// Outcome of an SMS-composer dispatch attempt.
enum SmsDispatchResult {
  /// The composer was opened successfully. We cannot determine whether
  /// the user actually tapped Send — Android's intent system does not
  /// surface that signal back to the launching app.
  composerOpened,

  /// No SMS-capable app is installed on the device, or the OS refused
  /// to handle the sms: URI scheme.
  noSmsAppAvailable,

  /// An error occurred while building or invoking the URI.
  error,
}

/// Wraps url_launcher's sms: URI scheme with a clean Flutter-side
/// interface. Stages a payload in the device's native SMS composer
/// pre-filled with the recipient and body; the caregiver confirms
/// transmission with one tap.
///
/// This is the "remote SMS pathway" of the hybrid sync architecture
/// (Section 3.5.4 of the project report).
class SmsDispatcher {
  /// Open the SMS composer with [recipient] and [body] prefilled.
  ///
  /// On Android, this issues an `Intent.ACTION_SENDTO` with the `sms:`
  /// URI scheme — a stable Android API since v1, available in every
  /// supported Android version.
  Future<SmsDispatchResult> dispatch({
    required String recipient,
    required String body,
  }) async {
    try {
      // Build the sms: URI by hand. Routing the body through Uri's
      // queryParameters map encodes spaces as '+', which some OEM SMS
      // apps (notably HiOS on Android 8.1) mishandle — dropping the body
      // entirely once the query string grows long. Percent-encoding the
      // body with encodeComponent and appending it as a raw ?body=...
      // is handled far more reliably across composers.
      final uri = Uri.parse(
        'sms:$recipient?body=${Uri.encodeComponent(body)}',
      );

      if (!await canLaunchUrl(uri)) {
        return SmsDispatchResult.noSmsAppAvailable;
      }

      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return ok ? SmsDispatchResult.composerOpened
                : SmsDispatchResult.error;
    } catch (_) {
      return SmsDispatchResult.error;
    }
  }
}
