import '../models/product.dart';
import 'api_client.dart';

class ProductService {
  final ApiClient _api;

  ProductService(this._api);

  Future<List<Product>> list() async {
    final data = await _api.get('/products');
    final items = data['data'] as List;
    return items.map((e) => Product.fromJson(e)).toList();
  }

  /// Quick-add a new product from the field — used when a sales rep is
  /// taking an order and the store wants something not yet in the catalog.
  /// `categoryId` is optional: the backend files it under "Uncategorized"
  /// when omitted, same as it does for a missing supplier.
  Future<Product> create({
    required String name,
    required double sellingPrice,
    int? categoryId,
    String? unit,
    int stockQuantity = 0,
  }) async {
    final data = await _api.post('/products', {
      'name': name,
      'selling_price': sellingPrice,
      if (categoryId != null) 'category_id': categoryId,
      if (unit != null && unit.isNotEmpty) 'unit': unit,
      'stock_quantity': stockQuantity,
    });
    return Product.fromJson(data);
  }

  Future<List<ProductCategory>> categories() async {
    final data = await _api.get('/categories');
    final items = data['data'] as List;
    return items.map((e) => ProductCategory.fromJson(e)).toList();
  }
}
