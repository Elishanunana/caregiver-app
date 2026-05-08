import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caregiver_app/services/pin_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PinSessionService', () {
    test('starts locked', () {
      final svc = PinSessionService();
      expect(svc.isUnlocked, isFalse);
      svc.dispose();
    });

    test('markUnlocked sets isUnlocked true', () {
      final svc = PinSessionService()..register();
      svc.markUnlocked();
      expect(svc.isUnlocked, isTrue);
      svc.dispose();
    });

    test('lock clears the unlock', () {
      final svc = PinSessionService()..register();
      svc.markUnlocked();
      svc.lock();
      expect(svc.isUnlocked, isFalse);
      svc.dispose();
    });

    test('background lifecycle states clear the unlock', () {
      final svc = PinSessionService()..register();
      svc.markUnlocked();

      // Simulate the framework calling didChangeAppLifecycleState.
      svc.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(svc.isUnlocked, isFalse);

      svc.markUnlocked();
      svc.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(svc.isUnlocked, isFalse);

      svc.dispose();
    });

    test('resumed lifecycle does NOT re-unlock', () {
      final svc = PinSessionService()..register();
      // Starting locked.
      svc.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(svc.isUnlocked, isFalse);
      svc.dispose();
    });
  });
}
