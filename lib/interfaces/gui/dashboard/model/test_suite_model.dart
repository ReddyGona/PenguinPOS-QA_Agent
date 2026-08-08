import 'package:flutter/material.dart';

/// A prerequisite that must be satisfied before a scenario can be executed.
///
/// These are descriptive requirements only. They never contain credential or
/// test-data values, which continue to be supplied through the configured QA
/// profile and execution flow.
enum QaTestRequirement {
  approvedNonProductionProfile,
  savedLoginCredentials,
  authenticatedSession,
  configuredTestItems,
}

/// Environment eligibility for a suite. Specific profile availability is
/// resolved at runtime from the user's configured profiles.
enum QaEnvironmentPolicy { approvedNonProductionOnly }

/// Represents a scenario within a test suite.
class TestSuiteScenario {
  const TestSuiteScenario({
    required this.id,
    required this.name,
    required this.tags,
    required this.stepsDescription,
    required this.purpose,
    required this.preconditions,
    required this.expectedOutcomes,
    this.requirements = const <QaTestRequirement>[],
    this.searchAliases = const <String>[],
  });

  final String id;
  final String name;
  final List<String> tags;
  final List<String> stepsDescription;
  final String purpose;
  final List<String> preconditions;
  final List<String> expectedOutcomes;
  final List<QaTestRequirement> requirements;
  final List<String> searchAliases;
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
    this.feature = '',
    this.purpose = '',
    this.searchAliases = const <String>[],
    this.environmentPolicy = QaEnvironmentPolicy.approvedNonProductionOnly,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<TestSuiteScenario> scenarios;
  final bool isImplemented;
  final String feature;
  final String purpose;
  final List<String> searchAliases;
  final QaEnvironmentPolicy environmentPolicy;

  static const List<TestSuiteItem> availableSuites = <TestSuiteItem>[
    TestSuiteItem(
      id: 'login_terminal',
      title: 'Login & Terminal',
      description:
          'Validates empty credential inputs, invalid credential handling, valid login flow, terminal selection, and home screen navigation.',
      icon: Icons.login_rounded,
      isImplemented: true,
      feature: 'Login & Terminal',
      purpose:
          'Verify that the login journey handles validation and authentication safely, then reaches a ready home screen after terminal selection.',
      searchAliases: <String>[
        'login',
        'authentication',
        'terminal',
        'sign in',
        'home screen',
      ],
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
          purpose: 'Confirm required Login ID and Password validation.',
          preconditions: <String>['PenguinPOS is on the login screen.'],
          expectedOutcomes: <String>[
            'A field validation error is shown.',
            'The user remains on the login screen.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
          ],
          searchAliases: <String>['blank login', 'empty password'],
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
          purpose: 'Confirm invalid credentials are rejected safely.',
          preconditions: <String>['PenguinPOS is on the login screen.'],
          expectedOutcomes: <String>[
            'An unauthorized or invalid-credential alert is shown.',
            'The user remains unauthenticated.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
          ],
          searchAliases: <String>[
            'invalid login',
            'authentication failure',
            'unauthorized',
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
          purpose:
              'Verify a saved QA login can select a terminal and reach a ready home screen.',
          preconditions: <String>[
            'PenguinPOS is on the login screen.',
            'A selectable terminal is available for the QA profile.',
          ],
          expectedOutcomes: <String>[
            'Terminal selection is shown after successful authentication.',
            'The selected terminal continues to an active home screen.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.savedLoginCredentials,
          ],
          searchAliases: <String>[
            'valid login',
            'terminal selection',
            'login flow',
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
      feature: 'Order & Cash Payment',
      purpose:
          'Verify an authenticated cashier can build a sale, enter regular or weighed items, and complete a rounded cash payment.',
      searchAliases: <String>[
        'order',
        'sale',
        'checkout',
        'cash',
        'payment',
        'sku',
        'weighed item',
        'cart',
      ],
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
          purpose: 'Verify a sale can start with the available customer flow.',
          preconditions: <String>[
            'An authenticated session is on the order screen.',
          ],
          expectedOutcomes: <String>[
            'The order table and number-pad controls are available for sale entry.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
          ],
          searchAliases: <String>['start sale', 'customer', 'order screen'],
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
          purpose: 'Verify regular SKU and weighed-item entry into the cart.',
          preconditions: <String>[
            'An authenticated session is on the order screen.',
            'The supplied test items are valid for the QA profile.',
          ],
          expectedOutcomes: <String>[
            'Each supplied item is accepted into the cart.',
            'Weighed items request and accept a weight before cart entry.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
            QaTestRequirement.configuredTestItems,
          ],
          searchAliases: <String>['scan sku', 'weight', 'weighed', 'add item'],
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
          purpose:
              'Verify cash checkout calculates round-off and completes an order.',
          preconditions: <String>[
            'An authenticated session has a cart with valid test items.',
          ],
          expectedOutcomes: <String>[
            'The payment screen shows a payable total.',
            'Cash payment accepts the rounded payable amount.',
            'The order success screen appears and the order can be completed.',
          ],
          requirements: <QaTestRequirement>[
            QaTestRequirement.approvedNonProductionProfile,
            QaTestRequirement.authenticatedSession,
            QaTestRequirement.configuredTestItems,
          ],
          searchAliases: <String>[
            'cash payment',
            'round off',
            'place order',
            'checkout',
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
