/// Telemetry metrics for intercepted API calls.
class OrderApiTelemetry {
  const OrderApiTelemetry({
    required this.endpoint,
    required this.statusCode,
    required this.responseTimeMs,
  });

  final String endpoint;
  final int statusCode;
  final int responseTimeMs;
}

/// Execution metric for an individual order step.
class OrderStepMetric {
  const OrderStepMetric({
    required this.stepName,
    required this.uiRenderTimeMs,
    this.apiTelemetry,
  });

  final String stepName;
  final int uiRenderTimeMs;
  final OrderApiTelemetry? apiTelemetry;
}

/// Metrics recorded for one order in a multi-order batch run.
class OrderLoopMetrics {
  const OrderLoopMetrics({
    required this.loopIndex,
    required this.durationMs,
    required this.itemsCount,
    required this.totalPayable,
    required this.payableCash,
    required this.stepMetrics,
  });

  final int loopIndex;
  final int durationMs;
  final int itemsCount;
  final double totalPayable;
  final int payableCash;
  final List<OrderStepMetric> stepMetrics;
}
