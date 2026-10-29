class SaleItemInput {
  final int productId;
  final int quantity;

  /// 'percent' or 'amount' — which of [discountPercent]/[discountAmount] the
  /// backend should actually apply (the other is sent as 0).
  final String discountType;
  final double discountPercent;
  final double discountAmount;

  SaleItemInput({
    required this.productId,
    required this.quantity,
    this.discountType = 'percent',
    this.discountPercent = 0,
    this.discountAmount = 0,
  });

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'discount_type': discountType,
        'discount_percent': discountPercent,
        'discount_amount': discountAmount,
      };
}

/// A product being returned from an earlier purchase, applied as a credit
/// against the new sale's total.
class ReturnInput {
  final int saleItemId;
  final int quantity;

  ReturnInput({required this.saleItemId, required this.quantity});

  Map<String, dynamic> toJson() => {
        'sale_item_id': saleItemId,
        'quantity': quantity,
      };
}

class Sale {
  final int id;
  final String invoiceNumber;
  final String paymentType;
  final double totalAmount;
  final DateTime saleDate;
  final String status;
  final String? customerName;
  final String? customerPhone;

  Sale({
    required this.id,
    required this.invoiceNumber,
    required this.paymentType,
    required this.totalAmount,
    required this.saleDate,
    this.status = 'completed',
    this.customerName,
    this.customerPhone,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'],
      invoiceNumber: json['invoice_number'],
      paymentType: json['payment_type'],
      totalAmount: double.parse(json['total_amount'].toString()),
      saleDate: DateTime.parse(json['sale_date']),
      status: json['status'] ?? 'completed',
      customerName: json['customer'] != null ? json['customer']['name'] : null,
      customerPhone: json['customer'] != null ? json['customer']['phone'] : null,
    );
  }
}
