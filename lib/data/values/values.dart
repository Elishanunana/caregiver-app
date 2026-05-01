/// String constants for fields whose backend values form a fixed enumeration.
///
/// We keep these as Strings (not Dart enums) to make wire-format equivalence
/// with the hub's Python repositories trivially obvious — a value flowing
/// through Hive, REST JSON, or SMS payload is always the same identifier
/// recognised by the hub's repositories.
///
/// Reference: src/data_management/repositories.py (hub backend).
library;

/// Mirrors `sync_state` on SyncQueueEntry.
class SyncState {
  static const String pending  = 'pending';
  static const String inFlight = 'in_flight';
  static const String synced   = 'synced';
  static const String failed   = 'failed';

  static const List<String> all = [pending, inFlight, synced, failed];
  static bool isValid(String v) => all.contains(v);

  SyncState._();
}

/// Mirrors `change_type` on SyncQueueEntry.
class ChangeType {
  static const String insert = 'INSERT';
  static const String update = 'UPDATE';
  static const String delete = 'DELETE';

  static const List<String> all = [insert, update, delete];
  static bool isValid(String v) => all.contains(v);

  ChangeType._();
}

/// Mirrors `direction` on SyncQueueEntry — which way the change travels.
class SyncDirection {
  static const String hubToApp = 'Hub->App';
  static const String appToHub = 'App->Hub';

  static const List<String> all = [hubToApp, appToHub];
  static bool isValid(String v) => all.contains(v);

  SyncDirection._();
}

/// Mirrors `transport` on SyncQueueEntry — which pathway carried the change.
class SyncTransport {
  static const String wifiRest = 'wifi_rest';
  static const String sms      = 'sms';

  static const List<String> all = [wifiRest, sms];
  static bool isValid(String v) => all.contains(v);

  SyncTransport._();
}

/// Mirrors `prescribed_by` on MedicationSchedule — clinical traceability of
/// schedule origin (Section 3.5.2 of the project report).
class PrescribedBy {
  static const String caregiver  = 'caregiver';
  static const String pharmacist = 'pharmacist';
  static const String hubLocal   = 'hub_local';

  static const List<String> all = [caregiver, pharmacist, hubLocal];
  static bool isValid(String v) => all.contains(v);

  PrescribedBy._();
}

/// Mirrors `sync_method` on MedicationSchedule — pathway that delivered
/// the record to the authoritative store.
class SyncMethod {
  static const String appWifi  = 'app_wifi';
  static const String appSms   = 'app_sms';
  static const String hubLocal = 'hub_local';

  static const List<String> all = [appWifi, appSms, hubLocal];
  static bool isValid(String v) => all.contains(v);

  SyncMethod._();
}
