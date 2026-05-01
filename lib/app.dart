import 'package:flutter/material.dart';

/// Root application widget.
///
/// For Task 15, this renders a placeholder confirming Hive has opened
/// successfully and the app has booted. Subsequent tasks replace this
/// scaffold with the real navigation tree (Today, History, Pharmacist
/// Entry — Section 3.5.5 of the project report).
class CaregiverApp extends StatelessWidget {
  const CaregiverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caregiver Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20), // KNUST green seed
          brightness: Brightness.light,
        ),
      ),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatelessWidget {
  const _BootstrapScreen();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.health_and_safety_rounded,
                  size: 72,
                  color: colors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Caregiver Companion',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'KNUST COE 497',
                  style: text.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Local store ready',
                        style: text.bodyMedium?.copyWith(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
