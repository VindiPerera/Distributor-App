class SaleDetailItem {
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double discountPercent;
  final double discountedPrice;
  final double lineTotal;

  SaleDetailItem({
    this.productId = 0,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent = 0,
    required this.discountedPrice,
    required this.lineTotal,
  });

  factory SaleDetailItem.fromJson(Map<String, dynamic> json) {
    final unitPrice = double.parse(json['unit_price'].toString());
    return SaleDetailItem(
      productId: json['product_id'] ?? json['product']['id'] ?? 0,
      productName: json['product']['name'],
      quantity: json['quantity'],
      unitPrice: unitPrice,
      discountPercent: double.parse((json['discount_percent'] ?? 0).toString()),
      discountedPrice: double.parse(
        (json['discounted_price'] ?? unitPrice).toString(),
      ),
      lineTotal: double.parse(json['line_total'].toString()),
    );
  }
}

/// A product returned from an earlier purchase and credited against this
/// sale's total.
class SaleDetailReturn {
  final String productName;
  final int quantity;
  final double unitPrice;
  final double amount;

  SaleDetailReturn({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.amount,
  });

  factory SaleDetailReturn.fromJson(Map<String, dynamic> json) {
    return SaleDetailReturn(
      productName: json['product']['name'],
      quantity: json['quantity'],
      unitPrice: double.parse(json['unit_price'].toString()),
      amount: double.parse(json['amount'].toString()),
    );
  }
}

class SaleDetail {
  final int id;
  final String status;
  final int? customerId;
  final String? notes;
  final String invoiceNumber;
  final String paymentType;
  final String? paymentReference;
  final double subtotal;
  final double returnAmount;
  final double totalAmount;
  final DateTime saleDate;
  final String? customerName;
  final String? customerPhone;
  final String cashierName;
  final List<SaleDetailItem> items;
  final List<SaleDetailReturn> returns;

  SaleDetail({
    required this.id,
    this.status = 'completed',
    this.customerId,
    this.notes,
    required this.invoiceNumber,
    required this.paymentType,
    this.paymentReference,
    required this.subtotal,
    this.returnAmount = 0,
    required this.totalAmount,
    required this.saleDate,
    this.customerName,
    this.customerPhone,
    required this.cashierName,
    required this.items,
    this.returns = const [],
  });

  factory SaleDetail.fromJson(Map<String, dynamic> json) {
    return SaleDetail(
      id: json['id'],
      status: json['status'] ?? 'completed',
      customerId: json['customer_id'],
      notes: json['notes'],
      invoiceNumber: json['invoice_number'],
      paymentType: json['payment_type'],
      paymentReference: json['payment_reference'],
      subtotal: double.parse(
        (json['subtotal'] ?? json['total_amount']).toString(),
      ),
      returnAmount: double.parse((json['return_amount'] ?? 0).toString()),
      totalAmount: double.parse(json['total_amount'].toString()),
      saleDate: DateTime.parse(json['sale_date']),
      customerName: json['customer'] != null ? json['customer']['name'] : null,
      customerPhone: json['customer'] != null
          ? json['customer']['phone']
          : null,
      cashierName: json['user'] != null ? json['user']['name'] : '-',
      items: (json['items'] as List)
          .map((e) => SaleDetailItem.fromJson(e))
          .toList(),
      returns: json['returns'] != null
          ? (json['returns'] as List)
                .map((e) => SaleDetailReturn.fromJson(e))
                .toList()
          : const [],
    );
  }
}
