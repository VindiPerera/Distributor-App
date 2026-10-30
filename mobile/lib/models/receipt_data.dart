import 'sale_detail.dart';

class ReceiptLine {
  final String name;
  final int quantity;
  final double unitPrice;
  final double discountedPrice;
  final double lineTotal;

  ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.discountedPrice,
    required this.lineTotal,
  });
}

/// A returned product credited against this bill's total.
class ReceiptReturn {
  final String name;
  final int quantity;
  final double amount;

  ReceiptReturn({
    required this.name,
    required this.quantity,
    required this.amount,
  });
}

class ReceiptData {
  final String invoiceNumber;
  final DateTime date;
  final List<ReceiptLine> lines;
  final double subtotal;
  final List<ReceiptReturn> returns;
  final double total;
  final String paymentType;
  final String? paymentReference;
  final String? customerName;
  final String? customerPhone;
  final String cashierName;

  ReceiptData({
    required this.invoiceNumber,
    required this.date,
    required this.lines,
    required this.subtotal,
    this.returns = const [],
    required this.total,
    required this.paymentType,
    this.paymentReference,
    this.customerName,
    this.customerPhone,
    required this.cashierName,
  });

  double get returnAmount => returns.fold(0, (sum, r) => sum + r.amount);

  factory ReceiptData.fromSaleDetail(SaleDetail sale) {
    return ReceiptData(
      invoiceNumber: sale.invoiceNumber,
      // sale.saleDate comes from the API as UTC — convert to the device's
      // local time (Sri Lanka) so the printed/displayed receipt shows the
      // actual wall-clock time the sale happened, not the UTC clock time.
      date: sale.saleDate.toLocal(),
      lines: sale.items
          .map(
            (i) => ReceiptLine(
              name: i.productName,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
              discountedPrice: i.discountedPrice,
              lineTotal: i.lineTotal,
            ),
          )
          .toList(),
      subtotal: sale.subtotal,
      returns: sale.returns
          .map(
            (r) => ReceiptReturn(
              name: r.productName,
              quantity: r.quantity,
              amount: r.amount,
            ),
          )
          .toList(),
      total: sale.totalAmount,
      paymentType: sale.paymentType,
      paymentReference: sale.paymentReference,
      customerName: sale.customerName,
      customerPhone: sale.customerPhone,
      cashierName: sale.cashierName,
    );
  }
}
