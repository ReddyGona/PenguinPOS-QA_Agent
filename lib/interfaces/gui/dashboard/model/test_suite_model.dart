import 'package:flutter/material.dart';

/// Represents a scenario within a test suite.
class TestSuiteScenario {
  const TestSuiteScenario({
    required this.id,
    required this.name,
    required this.tags,
    required this.stepsDescription,
  });

  final String id;
  final String name;
  final List<String> tags;
  final List<String> stepsDescription;
}

/// Represents a test suite selectable from the sidebar.
class TestSuiteItem {
  const TestSuiteItem({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.scenarios,
    this.isImplemented = true,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<TestSuiteScenario> scenarios;
  final bool isImplemented;

  static const List<TestSuiteItem> availableSuites = <TestSuiteItem>[
    TestSuiteItem(
      id: 'login_terminal',
      title: 'Login & Terminal',
      description:
          'Validates empty credential inputs, invalid credential handling, valid login flow, terminal selection, and home screen navigation.',
      icon: Icons.login_rounded,
      isImplemented: true,
      scenarios: <TestSuiteScenario>[
        TestSuiteScenario(
          id: 'empty_credentials',
          name: 'Login Validation',
          tags: <String>['validation', 'login'],
          stepsDescription: <String>[
            'Launch PenguinPOS',
            'Leave Login ID and Password blank',
            'Tap Login button',
            'Verify field validation error toast is displayed',
          ],
        ),
        TestSuiteScenario(
          id: 'invalid_credentials',
          name: 'Auth Failure Handling',
          tags: <String>['security', 'login'],
          stepsDescription: <String>[
            'Enter non-existent Login ID (0000000000)',
            'Enter arbitrary password',
            'Tap Login button',
            'Verify server unauthorized / invalid credential alert',
          ],
        ),
        TestSuiteScenario(
          id: 'valid_login',
          name: 'Valid Login Flow',
          tags: <String>['smoke', 'critical_path'],
          stepsDescription: <String>[
            'Enter valid 10-digit Login ID',
            'Enter valid Test Password',
            'Tap Login button',
            'Wait for Terminal Selection screen (login.terminal.continue)',
            'Tap Continue on selected Terminal',
            'Assert Home Screen (home.screen) is active and ready',
          ],
        ),
      ],
    ),
    TestSuiteItem(
      id: 'order_checkout',
      title: 'Order & Cash Payment',
      description:
          'Executes complete end-to-end POS order creation, SKU scanning, weighed item entry, cart update, cash payment round-off, and order success wrap-up.',
      icon: Icons.shopping_cart_checkout_rounded,
      isImplemented: true,
      scenarios: <TestSuiteScenario>[
        TestSuiteScenario(
          id: 'start_sale_customer',
          name: 'Start Sale & Customer Handling',
          tags: <String>['sale', 'order'],
          stepsDescription: <String>[
            'Verify Order Screen (order.screen) is active',
            'If Start Sale Widget (order.sale.start) is visible, tap Continue Without Customer (sale.continuewithoutcustomer)',
            'Verify Order Table (order.table) and NumPad Section (order.numpad.section) are displayed',
          ],
        ),
        TestSuiteScenario(
          id: 'sku_cart_addition',
          name: 'SKU & Weighed Item Entry',
          tags: <String>['cart', 'sku'],
          stepsDescription: <String>[
            'Enter SKU code into Input Code field (order.numpad.input.code)',
            'If field switches to Input Weight (order.numpad.input.weight), enter weight amount and tap Enter',
            'Repeat for all test SKU items',
          ],
        ),
        TestSuiteScenario(
          id: 'cash_payment_checkout',
          name: 'Cash Payment & Round-Off',
          tags: <String>['payment', 'cash'],
          stepsDescription: <String>[
            'Tap Update Cart (order.update_cart) until Proceed To Pay (order.proceed_to_pay) is active',
            'Tap Proceed To Pay and navigate to Payment Screen (payment.screen)',
            'Read Total Payable (bill_summary.total_payable) and compute round-off payable amount',
            'Select Cash Payment (payment.cash), enter payableAmount via numpad, and tap Place Order (payment.place_order)',
            'Verify Order Success Screen (order.success.screen) and tap Done to complete order flow',
          ],
        ),
      ],
    ),
    // TestSuiteItem(
    //   id: 'api_regression',
    //   title: 'API Regression',
    //   description: 'Executes automated API integration & endpoint contract validation suites.',
    //   icon: Icons.alt_route_rounded,
    //   isImplemented: false,
    //   scenarios: <TestSuiteScenario>[],
    // ),
    // TestSuiteItem(
    //   id: 'e2e_smoke',
    //   title: 'E2E Smoke Tests',
    //   description: 'Executes end-to-end multi-terminal POS smoke test workflows.',
    //   icon: Icons.speed_rounded,
    //   isImplemented: false,
    //   scenarios: <TestSuiteScenario>[],
    // ),
  ];
}
