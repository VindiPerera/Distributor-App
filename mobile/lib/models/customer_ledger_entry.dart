class CustomerLedgerEntry {
  final int id;
  final String type;
  final double amount;
  final double balanceAfter;
  final DateTime createdAt;
  final String? referenceLabel;

  CustomerLedgerEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
    this.referenceLabel,
  });

  bool get isSale => type == 'sale';

  factory CustomerLedgerEntry.fromJson(Map<String, dynamic> json) {
    final referenceType = json['reference_type'] as String?;
    final reference = json['reference'] as Map<String, dynamic>?;
    String? referenceLabel;
    if (reference != null) {
      if (referenceType != null &&
          referenceType.contains('Sale') &&
          reference['invoice_number'] != null) {
        referenceLabel = reference['invoice_number'] as String;
      } else if (reference['method'] != null) {
        referenceLabel = (reference['method'] as String).replaceAll('_', ' ');
      }
    }
    return CustomerLedgerEntry(
      id: json['id'],
      type: json['type'],
      amount: double.parse(json['amount'].toString()),
      balanceAfter: double.parse(json['balance_after'].toString()),
      createdAt: DateTime.parse(json['created_at']),
      referenceLabel: referenceLabel,
    );
  }
}
