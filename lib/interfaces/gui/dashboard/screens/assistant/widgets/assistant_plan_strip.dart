import 'package:flutter/material.dart';

import 'package:penguin_pos_qa_agent/ai/models/ai_models.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/qa_dashboard_models.dart';

/// Test Plan Strip displayed only when an AI test plan is ready for review.
class AssistantPlanStrip extends StatelessWidget {
  const AssistantPlanStrip({
    super.key,
    required this.plan,
    required this.canRun,
    required this.profiles,
    required this.activeProfile,
    required this.onRunPlan,
  });

  final AiTestPlan plan;
  final bool canRun;
  final List<QaProfile> profiles;
  final QaProfile activeProfile;
  final VoidCallback onRunPlan;

  @override
  Widget build(BuildContext context) {
    final profile = profiles.firstWhere(
      (candidate) => candidate.id == plan.profileId,
      orElse: () => activeProfile,
    );

    final skuList = plan.items.map((i) => i.skuCode).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4F0),
        border: Border.all(color: const Color(0xFFC7C9C4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.playlist_add_check_rounded,
              size: 16,
              color: Color(0xFF658A7A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      profile.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C302E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCE4DF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan.isOrder ? 'Order' : 'Login',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF182A22),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  plan.isOrder
                      ? 'Target: ${plan.ordersCount} Order(s) · SKU: ${skuList.isEmpty ? "AUTO" : skuList}'
                      : 'Target: Full sequence login & PIN unlock',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF494C4A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF658A7A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: canRun ? onRunPlan : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 16),
            label: const Text(
              'Review & Run',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
