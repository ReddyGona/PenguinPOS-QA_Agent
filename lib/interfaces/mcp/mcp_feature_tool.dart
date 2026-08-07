import 'mcp_tool_definition.dart';
import 'mcp_tool_result.dart';

/// Standard interface for MCP feature tools.
abstract interface class McpFeatureTool {
  McpToolDefinition get definition;
  Future<McpToolResult> execute(Map<String, Object?> arguments);
}
