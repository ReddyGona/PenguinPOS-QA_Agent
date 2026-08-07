import 'package:flutter/material.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/model/test_suite_model.dart';
import 'package:penguin_pos_qa_agent/interfaces/gui/dashboard/screens/order/widgets/scenario_card.dart';

/// Test Cases & Instructions Tab Widget for Order & Cash Payment Suite.
class OrderInstructionsTab extends StatelessWidget {
  const OrderInstructionsTab({
    super.key,
    required this.suite,
    required this.lastExecutionPassed,
    required this.wasAppClosedByUser,
    required this.scenariosCompleted,
    required this.lastExecutionDetails,
    required this.expandedMap,
    required this.allExpanded,
    required this.onToggleExpandAll,
    required this.onToggleExpandScenario,
  });

  final TestSuiteItem suite;
  final bool? lastExecutionPassed;
  final bool wasAppClosedByUser;
  final List<String> scenariosCompleted;
  final String? lastExecutionDetails;
  final Map<String, bool> expandedMap;
  final bool allExpanded;

  final VoidCallback onToggleExpandAll;
  final ValueChanged<String> onToggleExpandScenario;

  @override
  Widget build(BuildContext context) {
    final hasRun = lastExecutionPassed != null || wasAppClosedByUser;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Scenarios & Execution Steps Header
          Row(
            children: <Widget>[
              Text(
                'Test Cases & Execution Scenarios (${suite.scenarios.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onToggleExpandAll,
                icon: Icon(
                  allExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 16,
                ),
                label: Text(allExpanded ? 'Collapse All' : 'Expand All'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Scenarios Cards List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: suite.scenarios.length,
            itemBuilder: (context, index) {
              final scenario = suite.scenarios[index];
              final isExpanded = expandedMap[scenario.id] ?? false;

              final isPassed =
                  hasRun &&
                  (lastExecutionPassed == true ||
                      scenariosCompleted.contains(scenario.name) ||
                      scenariosCompleted.contains(scenario.id));

              final isFailed =
                  hasRun &&
                  !isPassed &&
                  !wasAppClosedByUser &&
                  lastExecutionPassed == false &&
                  (scenariosCompleted.length == index ||
                      (!scenariosCompleted.contains(scenario.name) &&
                          !scenariosCompleted.contains(scenario.id)));

              return ScenarioCard(
                scenario: scenario,
                isExpanded: isExpanded,
                isPassed: isPassed,
                isFailed: isFailed,
                wasAppClosedByUser: wasAppClosedByUser,
                lastExecutionDetails: lastExecutionDetails,
                onToggleExpand: () => onToggleExpandScenario(scenario.id),
              );
            },
          ),
          const SizedBox(height: 20),

          // Flow Specifications & Target Keys Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF1D4ED8),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const <Widget>[
                      Text(
                        'Complete Order & Payment Automation Flow Specifications',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E40AF),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Detailed step-by-step sequence of keys, states, decisions, and logic to execute end-to-end POS order test flows.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Step 1 - Session & Login Probe Card
          _buildInstructionStepCard(
            stepNumber: 'Step 1',
            title: 'Initial App Launch & Session Check',
            description:
                'Probes active widget state using driver.waitForAnyKey. If Login Screen is present (Key("login.id")), fills credentials and submits terminal selection. If Idle Screen is active, enters 4-digit PIN via numpad keys.',
            keys: const <String>[
              'login.id',
              'login.password',
              'login.submit',
              'login.terminal.continue',
              'idle_timeout.numpad.digit.<digit>',
              'idle_timeout.unlock',
            ],
          ),

          // Step 2 - Order Layout Sync & Start Sale Card
          _buildInstructionStepCard(
            stepNumber: 'Step 2',
            title: 'Order Layout Sync & Start Sale',
            description:
                'Navigates to Order screen via Key("home.tab.order"). If Start Sale widget Key("order.sale.start") is visible, taps Key("sale.continuewithoutcustomer") to proceed into cart editing.',
            keys: const <String>[
              'home.tab.order',
              'order.screen',
              'order.sale.start',
              'sale.continuewithoutcustomer',
              'order.table',
            ],
          ),

          // Step 3 - SKU & Weighed Item Entry Card
          _buildInstructionStepCard(
            stepNumber: 'Step 3',
            title: 'SKU & Weighed Item Entry',
            description:
                'Enters SKU codes into Key("order.numpad.input.code") and submits via Key("order.numpad.enter"). For weighed items, enters manual weight into Key("order.numpad.input.weight") and submits.',
            keys: const <String>[
              'order.numpad.input.code',
              'order.numpad.digit.<0-9>',
              'order.numpad.enter',
              'order.numpad.input.weight',
            ],
          ),

          // Step 4 - Proceed to Pay & Cash Tender Round-Off Card
          _buildInstructionStepCard(
            stepNumber: 'Step 4',
            title: 'Proceed to Pay & Cash Tender Round-Off',
            description:
                'Taps Key("order.update_cart") and Key("order.proceed_to_pay"). Reads live payable string from Key("bill_summary.total_payable"), computes POS round-off, selects Key("payment.cash"), and enters tender digits via Key("payment.numpad.digit.<0-9>").',
            keys: const <String>[
              'order.update_cart',
              'order.proceed_to_pay',
              'bill_summary.total_payable',
              'payment.cash',
              'payment.cash.input',
              'payment.numpad.enter',
            ],
          ),

          // Step 5 - Order Success Completion & Telemetry Interception Card
          _buildInstructionStepCard(
            stepNumber: 'Step 5',
            title: 'Order Success Completion & Telemetry Interception',
            description:
                'Waits for Key("order.success.screen"). Checks for Key("order.success.done"); if absent, taps Key("order.success.print_order_summary") or Key("order.success.print_invoice"). Records real-time API response times and UI render latency for each step.',
            keys: const <String>[
              'order.success.screen',
              'order.success.done',
              'order.success.print_order_summary',
              'order.success.print_invoice',
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStepCard({
    required String stepNumber,
    required String title,
    required String description,
    required List<String> keys,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keys.map((key) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  key,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
