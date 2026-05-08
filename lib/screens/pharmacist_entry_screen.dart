import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repositories/elder_profile_repository.dart';
import '../data/repositories/medication_schedule_repository.dart';
import '../data/repositories/sync_queue_repository.dart';
import '../data/entities/sync_queue_entry.dart';
import '../data/values/values.dart';
import '../services/pin_session_service.dart';
import '../services/secure_settings_service.dart';
import '../services/sms_dispatcher.dart';
import '../services/sms_payload_builder.dart';
import 'pin_widgets.dart';
import '_app_bar_actions.dart';

/// Pharmacist Entry — the App→Hub data-entry pathway described in
/// Section 3.5.5 of the project report.
///
/// Flow:
///   1. PIN gate (first-time → set PIN; thereafter → enter PIN).
///   2. Form — drug name, dosage, time due, days of week.
///   3. Validation against the hub's schema constraints.
///   4. Build HMAC-signed payload byte-compatible with SMSPayloadHandler.
///   5. Locally upsert the schedule (with prescribed_by=pharmacist,
///      sync_method=app_sms) so it appears immediately on Today's Overview.
///   6. Enqueue a SyncQueue entry for tracking the App→Hub change.
///   7. Open the SMS composer with the payload prefilled to the hub's SIM.
class PharmacistEntryScreen extends StatefulWidget {
  final ElderProfileRepository elderRepo;
  final MedicationScheduleRepository scheduleRepo;
  final SyncQueueRepository syncRepo;
  final SecureSettingsService settings;
  final PinSessionService pinSession;

  const PharmacistEntryScreen({
    super.key,
    required this.elderRepo,
    required this.scheduleRepo,
    required this.syncRepo,
    required this.settings,
    required this.pinSession,
  });

  @override
  State<PharmacistEntryScreen> createState() => PharmacistEntryScreenState();
}

class PharmacistEntryScreenState extends State<PharmacistEntryScreen> {
  bool _gateChecked = false;
  bool _gateOpen = false;

  final _drugCtrl = TextEditingController();
  final _dosageCtrl = TextEditingController();
  TimeOfDay? _timeDue;
  String _daysOfWeek = 'DAILY';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // PIN gate is fired by MainScaffold when the user navigates to this
    // tab — not on screen construction. PharmacistEntryScreen is built
    // eagerly inside an IndexedStack, so initState fires at app launch
    // for all three tabs simultaneously; firing the gate here would
    // prompt the user before they've expressed intent to enter the
    // pharmacist flow.
  }

  /// Synchronously hide the form. Called by MainScaffold when the user
  /// navigates to this tab while the session is locked, so we don't
  /// flash a populated form for one frame before the PIN dialog appears.
  void hideFormForRelock() {
    if (_gateOpen) {
      setState(() => _gateOpen = false);
    }
  }

  /// Public entry point for MainScaffold to trigger the PIN gate when
  /// the user navigates to this tab. Idempotent — safe to call when the
  /// gate is already open (the early-return on isUnlocked handles that).
  Future<void> openIfNeeded() async {
    // The session is the authoritative answer. If the session is locked
    // (e.g., because the app was backgrounded), we re-fire the gate even
    // if the form is currently visible — _gateOpen is a UI render flag,
    // not a security boundary.
    if (widget.pinSession.isUnlocked) {
      // Make sure the UI matches the session state. If we got here from
      // a stale-form path, this is a no-op; otherwise it reveals the form.
      if (!_gateOpen) {
        setState(() {
          _gateChecked = true;
          _gateOpen = true;
        });
      }
      return;
    }

    // Session is locked. If the form is currently showing (stale), hide
    // it before prompting — the dialog should appear over the locked
    // state, not over a populated form the user shouldn't be looking at.
    if (_gateOpen) {
      setState(() => _gateOpen = false);
    }

    await _runPinGate();
  }

  Future<void> _runPinGate() async {
    // Fast path: PIN already entered earlier in this session.
    if (widget.pinSession.isUnlocked) {
      if (!mounted) return;
      setState(() {
        _gateChecked = true;
        _gateOpen = true;
      });
      return;
    }

    final hasPin = await widget.settings.hasPharmacistPin();
    if (!mounted) return;

    if (!hasPin) {
      final newPin = await PinSetupFlow.show(context);
      if (!mounted) return;
      if (newPin == null) {
        // User cancelled PIN setup. Render the locked state — they can
        // try again by leaving and returning to the tab.
        setState(() {
          _gateChecked = true;
          _gateOpen = false;
        });
        return;
      }
      await widget.settings.setPharmacistPin(newPin);
      if (!mounted) return;
      widget.pinSession.markUnlocked();
      setState(() {
        _gateChecked = true;
        _gateOpen = true;
      });
      return;
    }

    final pin = await widget.settings.getPharmacistPin();
    if (!mounted || pin == null) return;
    final unlocked = await PinEntryGate.show(context, pin);
    if (!mounted) return;

    if (unlocked) {
      widget.pinSession.markUnlocked();
    }
    setState(() {
      _gateChecked = true;
      _gateOpen = unlocked;
    });
    // Note: no Navigator.pop() on failure. The user stays on the tab in
    // its locked state; switching away and back re-fires the gate.
  }

  Future<void> _submit() async {
    final drug = _drugCtrl.text.trim();
    final dosage = _dosageCtrl.text.trim();
    final time = _timeDue == null
        ? ''
        : '${_timeDue!.hour.toString().padLeft(2, '0')}:${_timeDue!.minute.toString().padLeft(2, '0')}';

    final err = SmsPayloadBuilder.validateField(
      drugName: drug,
      dosage: dosage,
      timeDue: time,
    );
    if (err != null || drug.isEmpty || dosage.isEmpty) {
      _toast(err ?? 'Please complete all fields.');
      return;
    }

    final elder = widget.elderRepo.getPrimary();
    if (elder == null || elder.elderId == null) {
      _toast('No elder profile registered.');
      return;
    }

    setState(() => _sending = true);

    final hmacKey = await widget.settings.getPairingToken();
    final hubSim = await widget.settings.getHubSimNumber();

    final builder = SmsPayloadBuilder(hmacKey: hmacKey);

    String payload;
    try {
      payload = builder.buildInsert(
        elderId: elder.elderId!,
        drugName: drug,
        dosage: dosage,
        timeDue: time,
        daysOfWeek: _daysOfWeek,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _toast('Payload error: $e');
      return;
    }

    // Local-first: upsert into Hive immediately so the Today's Overview
    // reflects the new schedule even before the SMS is dispatched.
    final newSchedule = widget.scheduleRepo.buildPharmacistEntry(
      elderId: elder.elderId!,
      drugName: drug,
      dosage: dosage,
      timeDue: time,
      daysOfWeek: _daysOfWeek,
    );
    await widget.scheduleRepo.upsert(newSchedule);

    // Enqueue an App→Hub sync record. The change_id matches the one
    // embedded in the payload (extracted from the canonical fields).
    final changeId = _extractChangeId(payload);
    await widget.syncRepo.insert(SyncQueueEntry(
      changeId: changeId,
      entityType: 'MedicationSchedule',
      entityId: newSchedule.scheduleId ?? -1,
      changeType: ChangeType.insert,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      syncState: SyncState.pending,
      direction: SyncDirection.appToHub,
      transport: SyncTransport.sms,
      payload: payload,
    ));

    // Open the SMS composer.
    final dispatcher = SmsDispatcher();
    final result = await dispatcher.dispatch(
      recipient: hubSim,
      body: payload,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    switch (result) {
      case SmsDispatchResult.composerOpened:
        _toast('Composer opened — tap Send to transmit.');
        // Close the screen — the user is now in the Messages app.
        Navigator.of(context).pop();
        break;
      case SmsDispatchResult.noSmsAppAvailable:
        _toast('No SMS app installed on this device.');
        break;
      case SmsDispatchResult.error:
        _toast('Could not open SMS composer.');
        break;
    }
  }

  String _extractChangeId(String payload) {
    final parts = payload.split('|');
    return parts.length > 2 ? parts[2] : '';
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _drugCtrl.dispose();
    _dosageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_gateChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_gateOpen) {
      return _buildLockedState(context);
    }

    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacist Entry'),
        actions: [
          CommonAppBarActions(settings: widget.settings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.local_pharmacy_rounded,
                    color: colors.onTertiaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enter the medication directly from the dispensing label. The schedule will be transmitted to the hub via SMS.',
                    style: text.bodySmall?.copyWith(
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Drug name', style: text.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _drugCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. Amlodipine',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\|')),
            ],
          ),
          const SizedBox(height: 16),
          Text('Dosage', style: text.titleSmall),
          const SizedBox(height: 6),
          TextField(
            controller: _dosageCtrl,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'e.g. 5 mg',
            ),
            inputFormatters: [
              FilteringTextInputFormatter.deny(RegExp(r'\|')),
            ],
          ),
          const SizedBox(height: 16),
          Text('Time due', style: text.titleSmall),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _timeDue ?? const TimeOfDay(hour: 8, minute: 0),
              );
              if (picked != null) setState(() => _timeDue = picked);
            },
            icon: const Icon(Icons.schedule_rounded),
            label: Text(_timeDue == null
                ? 'Choose time'
                : '${_timeDue!.hour.toString().padLeft(2, '0')}:${_timeDue!.minute.toString().padLeft(2, '0')}'),
          ),
          const SizedBox(height: 16),
          Text('Days of week', style: text.titleSmall),
          const SizedBox(height: 6),
          _DaysSelector(
            value: _daysOfWeek,
            onChanged: (v) => setState(() => _daysOfWeek = v),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sms_rounded),
            label: const Text('Build Payload & Open SMS'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacist Entry'),
        actions: [CommonAppBarActions(settings: widget.settings)],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 64, color: colors.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Pharmacist Entry is locked',
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the four-digit PIN to add medications to the schedule.',
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _runPinGate(),
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaysSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _DaysSelector({required this.value, required this.onChanged});

  static const _shortDays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

  @override
  Widget build(BuildContext context) {
    final isDaily = value == 'DAILY';
    final selectedDays = isDaily ? <String>{} : value.split(',').toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ChoiceChip(
              label: const Text('Daily'),
              selected: isDaily,
              onSelected: (_) => onChanged('DAILY'),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Specific days'),
              selected: !isDaily,
              onSelected: (_) => onChanged('MON'), // default starting set
            ),
          ],
        ),
        if (!isDaily) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _shortDays.map((d) {
              final picked = selectedDays.contains(d);
              return FilterChip(
                label: Text(d),
                selected: picked,
                onSelected: (_) {
                  final next = Set<String>.from(selectedDays);
                  if (picked) {
                    next.remove(d);
                  } else {
                    next.add(d);
                  }
                  if (next.isEmpty) {
                    onChanged('DAILY');
                  } else {
                    final ordered = _shortDays.where(next.contains).toList();
                    onChanged(ordered.join(','));
                  }
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
