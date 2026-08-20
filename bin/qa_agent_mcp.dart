import 'package:penguin_pos_qa_agent/qa_agent.dart';

/// Entrypoint for the MCP stdio server.
Future<void> main() async {
  final server = PenguinPosMcpServer(
    tools: <McpFeatureTool>[LoginFeatureTool()],
  );
  await server.listenStdio();
}
