import 'package:flutter/material.dart';

/// Project metadata surface — accessible from Settings.
///
/// Exists to give the defense panel one consolidated place to verify
/// authorship, supervisor, course code, and project version. Section
/// 1.0 of the project report establishes these as the canonical
/// metadata for COE 497 deliverables.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Icon(
              Icons.health_and_safety_rounded,
              size: 64,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Caregiver Companion',
              style: text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Version 0.1.0',
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(height: 32),
          _Section(
            title: 'Project',
            text: text,
            colors: colors,
            children: [
              _Row(
                label: 'Course',
                value: 'COE 497 — Final Year Project',
                text: text,
              ),
              _Row(
                label: 'Department',
                value: 'Computer Engineering, KNUST',
                text: text,
              ),
              _Row(
                label: 'Supervisor',
                value: 'Dr. Theresa S. A. Adjaidoo',
                text: text,
              ),
            ],
          ),

          const SizedBox(height: 16),
          _Section(
            title: 'Team',
            text: text,
            colors: colors,
            children: [
              _Row(
                label: 'Software',
                value: 'Akabua Elisha Nunana — 1815222',
                text: text,
              ),
              _Row(
                label: 'Hardware',
                value: 'Danso Nicole Kusiwaa — 1821022',
                text: text,
              ),
              _Row(
                label: 'Hardware',
                value: 'Asumang Pobi Godwin — 1818822',
                text: text,
              ),
            ],
          ),

          const SizedBox(height: 16),
          _Section(
            title: 'System',
            text: text,
            colors: colors,
            children: [
              _Row(label: 'Hub', value: 'Raspberry Pi 4', text: text),
              _Row(
                label: 'Companion',
                value: 'Flutter (Android)',
                text: text,
              ),
              _Row(
                label: 'Local store',
                value: 'Hive (encrypted at rest)',
                text: text,
              ),
              _Row(
                label: 'Sync',
                value: 'Wi-Fi REST + SMS payload',
                text: text,
              ),
            ],
          ),

          const SizedBox(height: 32),
          Center(
            child: Text(
              '© 2026 KNUST College of Engineering',
              style: text.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final TextTheme text;
  final ColorScheme colors;

  const _Section({
    required this.title,
    required this.children,
    required this.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final TextTheme text;

  const _Row({required this.label, required this.value, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: text.bodyMedium),
          ),
        ],
      ),
    );
  }
}
