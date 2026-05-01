import 'package:flutter/material.dart';

import 'app.dart';
import 'utils/hive_initializer.dart';

/// Application entry point.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveInitializer.init();
  runApp(const CaregiverApp());
}
