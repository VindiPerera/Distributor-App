/// One line item from a customer's earlier purchase that still has some
/// quantity left to return (not yet returned in a later sale).
class ReturnableItem {
  final int saleItemId;
  final int productId;
  final String productName;
  final int purchasedQuantity;
  final int returnedQuantity;
  final int returnableQuantity;
  final double unitPrice;

  ReturnableItem({
    required this.saleItemId,
    required this.productId,
    required this.productName,
    required this.purchasedQuantity,
    required this.returnedQuantity,
    required this.returnableQuantity,
    required this.unitPrice,
  });

  factory ReturnableItem.fromJson(Map<String, dynamic> json) {
    return ReturnableItem(
      saleItemId: json['id'],
      productId: json['product_id'],
      productName: json['product_name'],
      purchasedQuantity: json['quantity'],
      returnedQuantity: json['returned_quantity'] ?? 0,
      returnableQuantity: json['returnable_quantity'],
      unitPrice: double.parse(json['unit_price'].toString()),
    );
  }
}

/// A past sale of this customer's, with only the line items that still have
/// something left to return.
class ReturnableSale {
  final int id;
  final String invoiceNumber;
  final DateTime saleDate;
  final List<ReturnableItem> items;

  ReturnableSale({
    required this.id,
    required this.invoiceNumber,
    required this.saleDate,
    required this.items,
  });

  factory ReturnableSale.fromJson(Map<String, dynamic> json) {
    return ReturnableSale(
      id: json['id'],
      invoiceNumber: json['invoice_number'],
      saleDate: DateTime.parse(json['sale_date']),
      items: (json['items'] as List)
          .map((e) => ReturnableItem.fromJson(e))
          .toList(),
    );
  }
}
