import '../models/sale.dart';
import '../models/sale_detail.dart';
import 'api_client.dart';

class SaleService {
  final ApiClient _api;

  SaleService(this._api);

  Future<Map<String, dynamic>> createSale({
    required int customerId,
    required String paymentType,
    required List<SaleItemInput> items,
    double? paidAmount,
    String? paymentReference,
    List<ReturnInput>? returns,
  }) async {
    return await _api.post('/sales', {
      'customer_id': customerId,
      'payment_type': paymentType,
      if (paidAmount != null) 'paid_amount': paidAmount,
      if (paymentReference != null && paymentReference.isNotEmpty)
        'payment_reference': paymentReference,
      'items': items.map((e) => e.toJson()).toList(),
      if (returns != null && returns.isNotEmpty)
        'returns': returns.map((e) => e.toJson()).toList(),
    });
  }

  /// [search] matches the customer's name or the order id / number.
  Future<List<Sale>> list({String? search}) async {
    final term = search?.trim() ?? '';
    final data = await _api.get(
      '/sales',
      query: term.isEmpty ? null : {'search': term},
    );
    final items = data['data'] as List;
    return items.map((e) => Sale.fromJson(e)).toList();
  }

  Future<SaleDetail> get(int id) async {
    final data = await _api.get('/sales/$id');
    return SaleDetail.fromJson(data);
  }

  /// Places an order taken from a customer. No bill is issued; the order
  /// lands as pending for the back office to process.
  Future<Map<String, dynamic>> createOrder({
    required int customerId,
    required List<SaleItemInput> items,
    String? notes,
  }) async {
    return await _api.post('/sales', {
      'customer_id': customerId,
      'payment_type': 'credit',
      'items': items.map((e) => e.toJson()).toList(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  /// Replaces the items/notes of a pending order.
  Future<void> updateOrder(
    int id, {
    required List<SaleItemInput> items,
    String? notes,
  }) async {
    await _api.put('/sales/$id', {
      'items': items.map((e) => e.toJson()).toList(),
      'notes': notes ?? '',
    });
  }

  Future<void> cancelOrder(int id) async {
    await _api.post('/sales/$id/cancel', {});
  }
}
