enum QaTargetMode { local, ssh }

enum QaActivityKind { info, success, error }

class QaActivityMessage {
  QaActivityMessage(this.title, this.body, this.kind, {DateTime? at})
    : at = at ?? DateTime.now();

  final String title;
  final String body;
  final QaActivityKind kind;
  final DateTime at;
}
