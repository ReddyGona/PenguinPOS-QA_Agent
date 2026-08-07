# PenguinPOS integration requirements

This document is the contract between the PenguinPOS application and the
external QA Agent. It applies to debug and QA builds only. It does not grant the
QA Agent access to production or live systems.

## Debug-only driver endpoint

PenguinPOS must expose a Flutter Driver endpoint only in an explicitly enabled
debug or QA build. Gate it before `runApp`:

```dart
import 'package:flutter_driver/driver_extension.dart';

if (const bool.fromEnvironment('ENABLE_FLUTTER_DRIVER')) {
  enableFlutterDriverExtension();
}
```

Start the QA build with the corresponding `--dart-define`. Never enable this
extension in a production package or release deployment.

## Stable widget keys

Driver automation locates controls by these semantic keys. Renaming or removing
a key is a breaking change to the QA contract; update the QA Agent and its tests
in the same change.

### Login and terminal

| Key | Purpose |
| --- | --- |
| `login.id` | Login ID field |
| `login.password` | Password field |
| `login.submit` | Submit login credentials |
| `login.terminal.continue` | Continue after terminal selection |

### Order and cart

| Key | Purpose |
| --- | --- |
| `order.screen` | Order screen is available |
| `order.sale.start` | Start-sale state is available |
| `order.table` | Cart/order table is visible |
| `order.numpad.section` | Order numpad is visible |
| `order.numpad.input.code` | SKU/barcode input |
| `order.numpad.input.weight` | Manual weight input |
| `order.numpad.input.quantity` | Quantity input |
| `order.numpad.digit.<0-9>` | A numeric order-numpad key |
| `order.numpad.enter` | Submit the current item entry |
| `order.update_cart` | Update the cart |
| `order.proceed_to_pay` | Continue to payment |

### Payment and completion

| Key | Purpose |
| --- | --- |
| `payment.screen` | Payment screen is available |
| `payment.cash` | Choose cash payment |
| `payment.cash.input` | Cash amount input |
| `payment.numpad.digit.<0-9>` | A numeric payment-numpad key |
| `payment.numpad.enter` | Submit the payment amount |
| `payment.place_order` | Finalise the order |
| `order.success.screen` | Order success state is visible |
| `order.success.done` | Finish the success flow |

The additional invoice and print keys are defined in
`lib/automation/order/order_keys.dart` and should stay aligned with the
PenguinPOS widgets when those options are enabled.

## Behavioural assumptions

- Tests may start from login, terminal selection, or an idle/PIN-lock state.
- A weighed item must expose the manual-weight path after its SKU is entered.
- An order is successful only after the success screen is visible and its
  completion action can be taken.
- The app must expose stable, observable success and error states; visual text
  alone is not a durable automation contract.

## Responsibility boundaries

The QA Agent accepts natural-language requests and converts them into validated
test plans. PenguinPOS remains the source of truth for product catalog data,
prices, taxes, payments, stock, and order completion. Before enabling a new
workflow, provide:

1. stable widget keys for its controls and terminal states;
2. approved non-production test data and expected outcomes;
3. a cleanup or reset strategy for data that the test creates; and
4. deterministic success, error, and retry conditions.

The current assistant supports login and cash-order workflows. New workflows
(for example returns, coupons, card payments, inventory, or register actions)
need their own driver contract, validation rules, and tests before they are
advertised as executable.
