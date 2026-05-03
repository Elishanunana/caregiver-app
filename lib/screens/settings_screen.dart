import 'package:flutter/material.dart';

import '../services/hub_api_client.dart';
import '../services/secure_settings_service.dart';

/// Hub connection settings.
///
/// For the dev environment, the caregiver enters the hub's URL and
/// pairing token here, then taps "Test Connection" to verify that
/// the values authenticate correctly against the running hub. In
/// Task 22 this screen is replaced by a QR-code-based pairing flow.
class SettingsScreen extends StatefulWidget {
  final SecureSettingsService settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _hubUrlCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();
  final _simNumberCtrl = TextEditingController();

  bool _loading = true;
  bool _testing = false;
  HealthCheckResult? _lastResult;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final url = await widget.settings.getHubUrl();
    final token = await widget.settings.getPairingToken();
    final sim = await widget.settings.getHubSimNumber();
    if (!mounted) return;
    setState(() {
      _hubUrlCtrl.text = url;
      _tokenCtrl.text = token;
      _simNumberCtrl.text = sim;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await widget.settings.setHubUrl(_hubUrlCtrl.text.trim());
    await widget.settings.setPairingToken(_tokenCtrl.text.trim());
    await widget.settings.setHubSimNumber(_simNumberCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved.')),
    );
  }

  Future<void> _testConnection() async {
    final url = _hubUrlCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    if (url.isEmpty || token.isEmpty) {
      setState(() => _lastResult =
          const HealthCheckResult.unhealthy('Enter both URL and token.'));
      return;
    }

    setState(() {
      _testing = true;
      _lastResult = null;
    });

    final client = HubApiClient(baseUrl: url, pairingToken: token);
    final result = await client.checkHealth();
    client.close();

    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastResult = result;
    });
  }

  @override
  void dispose() {
    _hubUrlCtrl.dispose();
    _tokenCtrl.dispose();
    _simNumberCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Hub Connection')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Hub URL', style: text.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _hubUrlCtrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'http://10.0.2.2:5000',
              helperText:
                  'Use 10.0.2.2 from the Android emulator to reach the host laptop.',
            ),
          ),
          const SizedBox(height: 18),
          Text('Pairing Token', style: text.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _tokenCtrl,
            obscureText: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Token issued during pairing',
            ),
          ),

          const SizedBox(height: 18),
          Text('Hub SIM Number', style: text.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _simNumberCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '+233...',
              helperText:
                  'GSM number of the hub\'s SIM800L module. Used for the SMS sync pathway.',
            ),
          ),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon: _testing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.wifi_tethering_rounded),
                  label: const Text('Test'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_lastResult != null) _buildResultCard(_lastResult!, colors, text),
        ],
      ),
    );
  }

  Widget _buildResultCard(
      HealthCheckResult r, ColorScheme colors, TextTheme text) {
    final ok = r.isHealthy;
    final bg = ok ? colors.primaryContainer : colors.errorContainer;
    final fg = ok ? colors.onPrimaryContainer : colors.onErrorContainer;
    final icon = ok ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final title = ok ? 'Hub reachable' : 'Connection failed';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg),
              const SizedBox(width: 10),
              Text(title,
                  style: text.titleMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          if (ok) ...[
            Text('API version: ${r.apiVersion ?? "unknown"}',
                style: TextStyle(color: fg)),
            Text('Server time:  ${r.serverTime ?? "unknown"}',
                style: TextStyle(color: fg, fontFamily: 'monospace')),
          ] else
            Text(r.errorMessage ?? 'Unknown error',
                style: TextStyle(color: fg)),
        ],
      ),
    );
  }
}
