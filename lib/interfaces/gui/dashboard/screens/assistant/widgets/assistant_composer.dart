import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Rounded 18px Composer section with floating slash popup, attachment icon, text input, circular send button, and helper note.
class AssistantComposer extends StatelessWidget {
  const AssistantComposer({
    super.key,
    required this.inputController,
    required this.focusNode,
    required this.waiting,
    required this.running,
    required this.filteredSlashCommands,
    required this.slashSelectedIndex,
    required this.onSelectSlashCommand,
    required this.onSlashSelectedIndexChanged,
    required this.onSend,
  });

  final TextEditingController inputController;
  final FocusNode focusNode;
  final bool waiting;
  final bool running;
  final List<String> filteredSlashCommands;
  final int slashSelectedIndex;
  final ValueChanged<String> onSelectSlashCommand;
  final ValueChanged<int> onSlashSelectedIndexChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final showPopup = filteredSlashCommands.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (showPopup)
              Positioned(
                left: 0,
                right: 0,
                bottom: 64,
                child: _SlashPopup(
                  commands: filteredSlashCommands,
                  selectedIndex: slashSelectedIndex,
                  onSelectCommand: onSelectSlashCommand,
                ),
              ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFC7C9C4)),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x0C658A7A),
                    blurRadius: 14,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Attach scenario spec / open slash menu',
                      onPressed: waiting || running
                          ? null
                          : () => onSelectSlashCommand('/'),
                      icon: const Icon(
                        Icons.attach_file_rounded,
                        size: 20,
                        color: Color(0xFF787A76),
                      ),
                    ),
                    Expanded(
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent && showPopup) {
                            if (event.logicalKey ==
                                LogicalKeyboardKey.arrowDown) {
                              onSlashSelectedIndexChanged(
                                (slashSelectedIndex + 1) %
                                    filteredSlashCommands.length,
                              );
                              return KeyEventResult.handled;
                            } else if (event.logicalKey ==
                                LogicalKeyboardKey.arrowUp) {
                              onSlashSelectedIndexChanged(
                                (slashSelectedIndex -
                                        1 +
                                        filteredSlashCommands.length) %
                                    filteredSlashCommands.length,
                              );
                              return KeyEventResult.handled;
                            } else if (event.logicalKey ==
                                    LogicalKeyboardKey.tab ||
                                event.logicalKey == LogicalKeyboardKey.enter) {
                              onSelectSlashCommand(
                                filteredSlashCommands[slashSelectedIndex],
                              );
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: inputController,
                          focusNode: focusNode,
                          enabled: !waiting && !running,
                          onChanged: (_) => onSlashSelectedIndexChanged(0),
                          onSubmitted: (_) => onSend(),
                          maxLines: 5,
                          minLines: 1,
                          style: const TextStyle(
                            fontSize: 14.5,
                            color: Color(0xFF2C302E),
                          ),
                          decoration: const InputDecoration(
                            hintText:
                                'Ask QA Assistant or type / for actions...',
                            hintStyle: TextStyle(
                              color: Color(0xFF787A76),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: waiting || running
                          ? const Color(0xFFC7C9C4)
                          : const Color(0xFF658A7A),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: waiting || running ? null : onSend,
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Center(
                            child: waiting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        // Helper Note
        const SizedBox(height: 10),
        const Text(
          'Only approved non-production profiles can be executed.',
          style: TextStyle(fontSize: 12, color: Color(0xFF787A76)),
        ),
      ],
    );
  }
}

class _SlashPopup extends StatelessWidget {
  const _SlashPopup({
    required this.commands,
    required this.selectedIndex,
    required this.onSelectCommand,
  });

  final List<String> commands;
  final int selectedIndex;
  final ValueChanged<String> onSelectCommand;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFC7C9C4)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12658A7A),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.builder(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: commands.length,
          itemBuilder: (context, index) {
            final cmd = commands[index];
            final isSelected = index == selectedIndex;
            return Material(
              color: isSelected ? const Color(0xFFF6F4F0) : Colors.white,
              child: InkWell(
                onTap: () => onSelectCommand(cmd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.terminal_rounded,
                        size: 16,
                        color: Color(0xFF658A7A),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        cmd,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2C302E),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
