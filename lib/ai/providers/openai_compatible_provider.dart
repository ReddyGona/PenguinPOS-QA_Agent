import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/ai/providers/ai_model_provider.dart';

/// Works with Ollama, LM Studio, and cloud services exposing /v1/chat/completions.
class OpenAiCompatibleProvider implements AiModelProvider {
  OpenAiCompatibleProvider({
    required this.config,
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final AiModelConfig config;
  final String apiKey;
  final http.Client _client;

  Uri _endpoint(String suffix) {
    final base = config.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.parse('$base/$suffix');
    final isLoopback =
        uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
    if (!config.isCloud && !isLoopback) {
      throw ArgumentError(
        'Local model endpoints must use localhost, 127.0.0.1, or ::1.',
      );
    }
    if (config.isCloud && uri.scheme != 'https') {
      throw ArgumentError('Cloud model endpoints must use HTTPS.');
    }
    return uri;
  }

  Map<String, String> get _headers => <String, String>{
    'content-type': 'application/json',
    if (apiKey.trim().isNotEmpty) 'authorization': 'Bearer ${apiKey.trim()}',
  };

  @override
  Future<List<String>> listModels() async {
    final response = await _client
        .get(_endpoint('models'), headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Model server returned HTTP ${response.statusCode}.');
    }
    final payload = jsonDecode(response.body);
    final models = payload is Map ? payload['data'] : null;
    if (models is! List) return const <String>[];
    return models
        .whereType<Map>()
        .map((model) => model['id'] as String?)
        .whereType<String>()
        .where((model) => model.isNotEmpty)
        .toList();
  }

  @override
  Future<String> completeJson({
    required String systemPrompt,
    required List<AiChatMessage> messages,
    AiModelEventCallback? onEvent,
  }) async {
    if (!config.isConfigured) {
      throw StateError(
        'Configure an AI model before using natural-language chat.',
      );
    }

    onEvent?.call(
      const AiModelEvent(
        kind: AiModelEventKind.status,
        message: 'Connecting to the configured model…',
      ),
    );
    final request = http.Request('POST', _endpoint('chat/completions'))
      ..headers.addAll(_headers)
      ..body = jsonEncode(<String, Object?>{
        'model': config.model,
        'temperature': config.temperature,
        // Verbose reasoning is intentionally opt-in: Qwen3 can consume the
        // entire response on its trace before it has emitted JSON.
        'max_tokens': config.enableVerboseReasoning
            ? (config.maxOutputTokens < 5000 ? 5000 : config.maxOutputTokens)
            : config.maxOutputTokens,
        'response_format': const <String, String>{'type': 'json_object'},
        'reasoning_effort': config.enableVerboseReasoning ? 'low' : 'none',
        'stream': true,
        'messages': <Map<String, String>>[
          <String, String>{'role': 'system', 'content': systemPrompt},
          ...messages.map(
            (message) => <String, String>{
              'role': switch (message.role) {
                AiChatRole.user => 'user',
                AiChatRole.assistant => 'assistant',
                AiChatRole.system => 'system',
              },
              'content': message.text,
            },
          ),
        ],
      });
    final response = await _client
        .send(request)
        .timeout(const Duration(seconds: 45));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      onEvent?.call(
        AiModelEvent(
          kind: AiModelEventKind.error,
          message: 'Model server returned HTTP ${response.statusCode}.',
        ),
      );
      throw StateError(
        'Model server returned HTTP ${response.statusCode}: $body',
      );
    }

    onEvent?.call(
      AiModelEvent(
        kind: AiModelEventKind.status,
        message: config.enableVerboseReasoning
            ? 'Model is reasoning through the constrained QA plan…'
            : 'Structured-plan mode is preparing a fast validated response…',
      ),
    );
    final result = StringBuffer();
    String? finishReason;
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (!line.startsWith('data: ')) continue;
      final data = line.substring('data: '.length).trim();
      if (data == '[DONE]' || data.isEmpty) continue;
      final payload = jsonDecode(data);
      final choices = payload is Map ? payload['choices'] : null;
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        continue;
      }
      final choice = choices.first as Map;
      finishReason ??= choice['finish_reason'] as String?;
      final delta = choice['delta'];
      if (delta is! Map) continue;
      final reasoning = delta['reasoning'];
      if (reasoning is String && reasoning.isNotEmpty) {
        onEvent?.call(
          AiModelEvent(kind: AiModelEventKind.reasoning, message: reasoning),
        );
      }
      final content = delta['content'];
      if (content is String && content.isNotEmpty) {
        result.write(content);
        onEvent?.call(
          AiModelEvent(kind: AiModelEventKind.response, message: content),
        );
      }
    }

    if (result.isEmpty) {
      final message = finishReason == 'length'
          ? 'Model reached its output limit before returning the required JSON plan.'
          : 'Model response does not contain JSON content.';
      onEvent?.call(
        AiModelEvent(kind: AiModelEventKind.error, message: message),
      );
      throw FormatException(message);
    }
    onEvent?.call(
      const AiModelEvent(
        kind: AiModelEventKind.status,
        message: 'Final response received. Validating the plan JSON…',
      ),
    );
    return result.toString();
  }
}
