class ProductCategory {
  final int id;
  final String name;

  ProductCategory({required this.id, required this.name});

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(id: json['id'], name: json['name']);
  }
}

class Product {
  final int id;
  final String sku;
  final String name;
  final String unit;
  final double sellingPrice;
  final int stockQuantity;
  final String? imageUrl;
  final int? categoryId;
  final String? categoryName;

  Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.sellingPrice,
    required this.stockQuantity,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as Map<String, dynamic>?;
    return Product(
      id: json['id'],
      sku: json['sku'],
      name: json['name'],
      unit: json['unit'] ?? 'pcs',
      sellingPrice: double.parse(json['selling_price'].toString()),
      stockQuantity: json['stock_quantity'] ?? 0,
      imageUrl: json['image_url'],
      categoryId: category?['id'],
      categoryName: category?['name'],
    );
  }
}
