import 'package:flutter/material.dart';

import '../services/hub_api_client.dart';
import '../services/secure_settings_service.dart';

/// First-launch pairing flow.
///
/// Captures the hub's URL, the pairing token, and the hub's GSM SIM
/// number, then verifies the credentials by probing /health before
/// persisting them and marking the device as paired. This prevents
/// the app from being left in a half-paired state where credentials
/// are saved but don't actually authenticate.
///
/// Section 3.5.5 of the project report describes pairing as a one-time
/// ritual performed during initial setup; on a real deployment, the
/// pairing token would be transferred via QR code at the hub's
/// installation site. For the dev / academic-defense build we accept
/// manual entry — the verification step is what keeps this defensible.
class PairingScreen extends StatefulWidget {
  final SecureSettingsService settings;
  final VoidCallback onPaired;

  const PairingScreen({
    super.key,
    required this.settings,
    required this.onPaired,
  });

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _urlCtrl = TextEditingController(text: 'http://10.0.2.2:5000');
  final _tokenCtrl = TextEditingController(text: 'CHANGE_ME_ON_PAIRING');
  final _simCtrl = TextEditingController();

  bool _verifying = false;
  String? _error;
  bool _verified = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    _simCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _verifying = true;
      _error = null;
      _verified = false;
    });

    final url = _urlCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    if (url.isEmpty || token.isEmpty) {
      setState(() {
        _verifying = false;
        _error = 'Hub URL and pairing token are required.';
      });
      return;
    }

    final client = HubApiClient(baseUrl: url, pairingToken: token);
    final result = await client.checkHealth();
    client.close();

    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verified = result.isHealthy;
      _error = result.isHealthy ? null : (result.errorMessage ?? 'Hub unreachable.');
    });
  }

  Future<void> _completePairing() async {
    await widget.settings.setHubUrl(_urlCtrl.text.trim());
    await widget.settings.setPairingToken(_tokenCtrl.text.trim());
    if (_simCtrl.text.trim().isNotEmpty) {
      await widget.settings.setHubSimNumber(_simCtrl.text.trim());
    }
    await widget.settings.markPaired();
    if (!mounted) return;
    widget.onPaired();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Icon(
                  Icons.health_and_safety_rounded,
                  size: 56,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'Pair with Hub',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  'Enter the hub credentials, then verify the connection',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              Text('Hub URL', style: text.titleSmall),
              const SizedBox(height: 6),
              TextField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'http://10.0.2.2:5000',
                  helperText:
                      'Use 10.0.2.2 from the Android emulator. Use the laptop\'s IP from a real device.',
                  helperMaxLines: 2,
                ),
                onChanged: (_) => setState(() => _verified = false),
              ),
              const SizedBox(height: 18),

              Text('Pairing Token', style: text.titleSmall),
              const SizedBox(height: 6),
              TextField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Token from hub setup',
                ),
                onChanged: (_) => setState(() => _verified = false),
              ),
              const SizedBox(height: 18),

              Text('Hub SIM Number (optional)', style: text.titleSmall),
              const SizedBox(height: 6),
              TextField(
                controller: _simCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '+233...',
                  helperText:
                      'For the SMS sync pathway. Can be set later in Settings.',
                  helperMaxLines: 2,
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: colors.onErrorContainer, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_verified) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_rounded,
                          color: colors.onPrimaryContainer, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Hub reachable. Tap Complete Pairing to save.',
                          style: TextStyle(color: colors.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _verifying ? null : _verify,
                      icon: _verifying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.wifi_tethering_rounded),
                      label: Text(_verifying ? 'Verifying…' : 'Verify'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _verified ? _completePairing : null,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Complete'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
