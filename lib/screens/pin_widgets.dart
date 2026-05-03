import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal flow for setting the pharmacist PIN on first use.
///
/// Returns the chosen PIN if the user completed setup, or null if they
/// cancelled. The caller is responsible for persisting the result via
/// SecureSettingsService.
class PinSetupFlow extends StatefulWidget {
  const PinSetupFlow({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Dialog(child: PinSetupFlow()),
    );
  }

  @override
  State<PinSetupFlow> createState() => _PinSetupFlowState();
}

class _PinSetupFlowState extends State<PinSetupFlow> {
  final _firstCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;

  void _submit() {
    final a = _firstCtrl.text.trim();
    final b = _confirmCtrl.text.trim();
    if (a.length != 4 || !RegExp(r'^\d{4}$').hasMatch(a)) {
      setState(() => _error = 'PIN must be exactly 4 digits.');
      return;
    }
    if (a != b) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    Navigator.of(context).pop(a);
  }

  @override
  void dispose() {
    _firstCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Text('Set Pharmacist PIN',
                  style: text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Choose a 4-digit PIN. Pharmacy staff will enter this PIN at the counter to add medications to ${"the schedule"}.',
            style: text.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _firstCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: 'New PIN',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            decoration: const InputDecoration(
              labelText: 'Confirm PIN',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('Set PIN'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal PIN-entry gate. Returns true if the entered PIN matches the
/// expected value, false on cancel. The caller is responsible for any
/// subsequent action (e.g., revealing the Pharmacist Entry form).
class PinEntryGate extends StatefulWidget {
  final String expectedPin;

  const PinEntryGate({super.key, required this.expectedPin});

  static Future<bool> show(BuildContext context, String expectedPin) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(child: PinEntryGate(expectedPin: expectedPin)),
    );
    return ok ?? false;
  }

  @override
  State<PinEntryGate> createState() => _PinEntryGateState();
}

class _PinEntryGateState extends State<PinEntryGate> {
  final _ctrl = TextEditingController();
  String? _error;
  int _attempts = 0;

  void _submit() {
    final v = _ctrl.text.trim();
    if (v == widget.expectedPin) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _attempts++;
      _error = _attempts >= 3
          ? 'Too many incorrect attempts. Cancel and try again later.'
          : 'Incorrect PIN. ${3 - _attempts} attempt(s) remaining.';
      _ctrl.clear();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final lockedOut = _attempts >= 3;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: colors.primary),
              const SizedBox(width: 10),
              Text('Pharmacist PIN',
                  style: text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 4,
            enabled: !lockedOut,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Enter PIN',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: lockedOut ? null : _submit,
                  child: const Text('Unlock'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
