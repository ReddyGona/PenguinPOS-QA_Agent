enum QaTargetMode { local, ssh }

enum QaActivityKind { info, success, error }

class QaActivityMessage {
  const QaActivityMessage(this.title, this.body, this.kind);
  final String title;
  final String body;
  final QaActivityKind kind;
}

class QaProfile {
  const QaProfile({
    required this.label,
    required this.entity,
    required this.environment,
  });
  final String label;
  final String entity;
  final String environment;

  static const values = <QaProfile>[
    QaProfile(label: 'KPN STAGE', entity: 'kpn', environment: 'stage'),
    QaProfile(label: 'KPN DEV', entity: 'kpn', environment: 'dev'),
    QaProfile(label: 'IBO STAGE', entity: 'ibo', environment: 'stage'),
    QaProfile(label: 'IBO DEV', entity: 'ibo', environment: 'dev'),
    QaProfile(label: 'SAVO STAGE', entity: 'savomart', environment: 'stage'),
    QaProfile(label: 'SAVO DEV', entity: 'savomart', environment: 'dev'),
  ];
}
