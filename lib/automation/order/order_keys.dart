/// Stable widget keys forming the Order & Cash Payment QA contract with PenguinPOS.
abstract final class PenguinPosOrderKeys {
  static const homeOrderTab = 'home.tab.order';
  static const orderScreen = 'order.screen';
  static const orderSaleStart = 'order.sale.start';
  static const continueWithoutCustomer = 'sale.continuewithoutcustomer';
  static const orderTable = 'order.table';
  static const orderNumPadSection = 'order.numpad.section';
  static const orderInputCode = 'order.numpad.input.code';
  static const orderInputWeight = 'order.numpad.input.weight';
  static const orderInputQuantity = 'order.numpad.input.quantity';

  static String orderNumPadDigit(String n) => 'order.numpad.digit.$n';
  static const orderNumPadEnter = 'order.numpad.enter';

  static const orderUpdateCart = 'order.update_cart';
  static const orderProceedToPay = 'order.proceed_to_pay';

  static const paymentScreen = 'payment.screen';
  static const billSummaryTotalPayable = 'bill_summary.total_payable';
  static const paymentCash = 'payment.cash';
  static const paymentCashInput = 'payment.cash.input';

  static String paymentNumPadDigit(String n) => 'payment.numpad.digit.$n';
  static const paymentNumPadEnter = 'payment.numpad.enter';
  static const paymentPlaceOrder = 'payment.place_order';

  static const orderSuccessScreen = 'order.success.screen';
  static const orderSuccessAutoPlaceOrderEnabled =
      'order.success.auto_place_order.enabled';
  static const orderSuccessInvoicePending = 'order.success.invoice.pending';
  static const orderSuccessInvoiceReady = 'order.success.invoice.ready';
  static const orderSuccessPrintInvoiceEnabled =
      'order.success.print_invoice.enabled';
  static const orderSuccessPrintOrderSummaryEnabled =
      'order.success.print_order_summary.enabled';
  static const orderSuccessPrintOrderSummary =
      'order.success.print_order_summary';
  static const orderSuccessPrintInvoice = 'order.success.print_invoice';
  static const orderSuccessSmsInvoice = 'order.success.sms_invoice';
  static const orderSuccessDone = 'order.success.done';
}
