class ShopSettings {
  final String name;
  final String address;
  final String phone;
  final String companyPhone;
  final String taxId;
  final String footerNote;
  final String paperSize;
  final String receiptLanguage;

  const ShopSettings({
    required this.name,
    required this.address,
    required this.phone,
    required this.companyPhone,
    required this.taxId,
    required this.footerNote,
    required this.paperSize,
    required this.receiptLanguage,
  });

  static const fallback = ShopSettings(
    name: 'Your Shop',
    address: '',
    phone: '',
    companyPhone: '',
    taxId: '',
    footerNote: 'Thank you! Come again.',
    paperSize: 'mm58',
    receiptLanguage: 'en',
  );

  factory ShopSettings.fromJson(Map<String, dynamic> json) {
    return ShopSettings(
      name: (json['name'] as String?)?.isNotEmpty == true
          ? json['name']
          : fallback.name,
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      companyPhone: json['company_phone'] ?? '',
      taxId: json['tax_id'] ?? '',
      footerNote: json['footer_note'] ?? '',
      paperSize: (json['paper_size'] as String?)?.isNotEmpty == true
          ? json['paper_size']
          : fallback.paperSize,
      receiptLanguage: (json['receipt_language'] as String?)?.isNotEmpty == true
          ? json['receipt_language']
          : fallback.receiptLanguage,
    );
  }
}
