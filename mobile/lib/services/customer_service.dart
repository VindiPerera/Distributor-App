import '../models/customer.dart';
import '../models/customer_category.dart';
import '../models/customer_ledger_entry.dart';
import '../models/returnable_sale.dart';
import 'api_client.dart';

class CustomerService {
  final ApiClient _api;

  CustomerService(this._api);

  Future<List<Customer>> list({int? categoryId}) async {
    final data = await _api.get(
      '/customers',
      query: categoryId != null ? {'category_id': '$categoryId'} : null,
    );
    final items = data['data'] as List;
    return items.map((e) => Customer.fromJson(e)).toList();
  }

  Future<List<CustomerCategory>> categories() async {
    final data = await _api.get('/customer-categories');
    final items = data as List;
    return items.map((e) => CustomerCategory.fromJson(e)).toList();
  }

  Future<Customer> create({
    required String name,
    String? phone,
    String? address,
    int? categoryId,
    double creditLimit = 0,
  }) async {
    final data = await _api.post('/customers', {
      'name': name,
      'phone': phone,
      'address': address,
      'customer_category_id': categoryId,
      'credit_limit': creditLimit,
    });
    return Customer.fromJson(data);
  }

  Future<Map<String, dynamic>> recordPayment({
    required int customerId,
    required double amount,
    String method = 'cash',
    String? notes,
  }) async {
    return await _api.post('/payments', {
      'customer_id': customerId,
      'amount': amount,
      'method': method,
      'notes': notes,
    });
  }

  Future<List<CustomerLedgerEntry>> ledger(int customerId) async {
    final data = await _api.get('/customers/$customerId/ledger');
    final items = data['data'] as List;
    return items.map((e) => CustomerLedgerEntry.fromJson(e)).toList();
  }

  /// Past sales of this customer's that still have line items left to
  /// return — feeds the "Return a product" picker at checkout.
  Future<List<ReturnableSale>> returnableItems(int customerId) async {
    final data = await _api.get('/customers/$customerId/returnable-items');
    final items = data['data'] as List;
    return items.map((e) => ReturnableSale.fromJson(e)).toList();
  }
}
