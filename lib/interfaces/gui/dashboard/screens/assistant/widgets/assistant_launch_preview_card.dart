import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/assistant/widgets/assistant_ui_tokens.dart';

/// A compact final check displayed after validation and before launch.
class AssistantLaunchPreviewCard extends StatelessWidget {
  const AssistantLaunchPreviewCard({super.key, required this.preview});

  final AiRichLaunchPreview preview;

  @override
  Widget build(BuildContext context) {
    final isOrderPreview = preview.orders.isNotEmpty;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AssistantUiTokens.surface,
        borderRadius: AssistantUiTokens.cardRadius,
        border: Border.all(color: AssistantUiTokens.subtleBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  isOrderPreview
                      ? Icons.fact_check_rounded
                      : Icons.login_rounded,
                  size: 18,
                  color: AssistantUiTokens.success,
                ),
                SizedBox(width: 8),
                Text(
                  isOrderPreview
                      ? 'Final order allocation'
                      : 'Login execution plan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AssistantUiTokens.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${preview.workflowLabel} · ${preview.profileLabel} · '
              '${preview.orders.length} ${preview.orders.length == 1 ? 'order' : 'orders'} · '
              '${preview.totalItems} ${preview.totalItems == 1 ? 'item' : 'items'}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AssistantUiTokens.mutedText,
              ),
            ),
            const SizedBox(height: 14),
            if (!isOrderPreview)
              const Text(
                'The suite will validate login, select the terminal, verify the home screen, and log out.',
                style: TextStyle(
                  color: AssistantUiTokens.mutedText,
                  fontSize: 11.5,
                ),
              )
            else
              for (
                var index = 0;
                index < preview.orders.length;
                index++
              ) ...<Widget>[
                _OrderAllocationPanel(
                  order: preview.orders[index],
                  accent: _accentFor(index),
                ),
                if (index < preview.orders.length - 1)
                  const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  static Color _accentFor(int index) => switch (index % 3) {
    0 => const Color(0xFF2E7D32),
    1 => const Color(0xFF1565C0),
    _ => const Color(0xFF7B1FA2),
  };
}

class _OrderAllocationPanel extends StatelessWidget {
  const _OrderAllocationPanel({required this.order, required this.accent});

  final AiOrderLaunchPreview order;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.length;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${order.orderNumber}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Order ${order.orderNumber}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AssistantUiTokens.text,
                ),
              ),
              const Spacer(),
              Text(
                '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                style: TextStyle(
                  color: accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          if (order.items.isEmpty)
            const Text(
              'No items assigned',
              style: TextStyle(
                color: AssistantUiTokens.mutedText,
                fontSize: 11.5,
              ),
            )
          else
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'SKU ${item.skuCode} · ${item.typeLabel} · ${item.entryModeLabel}',
                  style: const TextStyle(
                    color: AssistantUiTokens.text,
                    fontSize: 11.5,
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
