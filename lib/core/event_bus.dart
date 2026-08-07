import 'dart:async';

import 'models.dart';

/// Lightweight in-memory event bus for broadcasting QA execution lifecycle events.
class EventBus {
  final _controller = StreamController<ExecutionEvent>.broadcast();

  Stream<ExecutionEvent> get stream => _controller.stream;

  void publish(ExecutionEvent event) {
    _controller.add(event);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
