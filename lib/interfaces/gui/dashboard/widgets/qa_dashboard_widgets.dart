import 'package:flutter/material.dart';

import '../model/qa_dashboard_models.dart';

class QaDashboardNavigation extends StatelessWidget {
  const QaDashboardNavigation({
    super.key,
    required this.showTests,
    required this.testsUnlocked,
    required this.onSetup,
    required this.onTests,
  });
  final bool showTests;
  final bool testsUnlocked;
  final VoidCallback onSetup;
  final VoidCallback onTests;

  @override
  Widget build(BuildContext context) => Container(
    width: 220,
    color: const Color(0xFF101828),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 32, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'PENGUINPOS',
                style: TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1.4,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'QA Agent',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        _NavigationItem(
          icon: Icons.tune_outlined,
          label: 'Setup',
          active: !showTests,
          onTap: onSetup,
        ),
        _NavigationItem(
          icon: Icons.fact_check_outlined,
          label: 'Test cases',
          active: showTests,
          enabled: testsUnlocked,
          onTap: onTests,
        ),
        const Spacer(),
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Phase 1 · Local execution\nSSH runner planned next.',
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class QaPanel extends StatelessWidget {
  const QaPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE4E7EC)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    ),
  );
}

class QaSectionTitle extends StatelessWidget {
  const QaSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
  );
}

class QaActivityPanel extends StatelessWidget {
  const QaActivityPanel({super.key, required this.messages});
  final List<QaActivityMessage> messages;
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return QaPanel(
      title: 'Run activity',
      subtitle: 'Execution events and final report data appear here.',
      child: ListView.separated(
        itemCount: messages.length,
        separatorBuilder: (_, _) => const Divider(height: 24),
        itemBuilder: (context, index) {
          final message = messages[index];
          final color = switch (message.kind) {
            QaActivityKind.success => Colors.green,
            QaActivityKind.error => Colors.red,
            QaActivityKind.info => palette.primary,
          };
          final icon = switch (message.kind) {
            QaActivityKind.success => Icons.check_circle_outline,
            QaActivityKind.error => Icons.error_outline,
            QaActivityKind.info => Icons.info_outline,
          };
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      message.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(message.body),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.enabled = true,
  });
  final IconData icon;
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    child: Material(
      color: active ? const Color(0xFF344054) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Icon(icon, color: enabled ? Colors.white : Colors.white38),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enabled ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
