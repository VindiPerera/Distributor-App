import 'api_client.dart';

/// In-memory stand-in for the Laravel API, used only when [kDemoMode] is on.
/// State lives for the app session, so placing, editing and cancelling an
/// order visibly works on the Orders screen.
class DemoApi {
  static final List<Map<String, dynamic>> _customers = [
    _customer(
      1,
      'Sunil Jayawardena',
      '0771234561',
      'No. 12, Galle Road, Colombo',
      52000,
      250000,
    ),
    _customer(
      2,
      'Nimali Fernando',
      '0712345678',
      '45, Temple Road, Kandy',
      0,
      100000,
    ),
    _customer(
      3,
      'Ruwan Traders',
      '0759876543',
      '8, Main Street, Galle',
      128500,
      300000,
    ),
    _customer(
      4,
      'Kamal Super Mart',
      '0764455667',
      '21, Station Road, Negombo',
      9800,
      150000,
    ),
    _customer(
      5,
      'Lanka Wholesale',
      '0701122334',
      '77, Hospital Road, Matara',
      0,
      500000,
    ),
  ];

  static final List<Map<String, dynamic>> _products = [
    _product(1, 'SKU-0001', 'Kleen Dish Wash 500ml', 'pcs', 285, 120),
    _product(2, 'SKU-0002', 'Kleen Floor Cleaner 1L', 'pcs', 560, 80),
    _product(3, 'SKU-0003', 'Kleen Hand Wash 250ml', 'pcs', 340, 150),
    _product(4, 'SKU-0004', 'Spirit Laundry Powder 1kg', 'pcs', 720, 60),
    _product(5, 'SKU-0005', 'Spirit Bleach 750ml', 'pcs', 410, 95),
    _product(6, 'SKU-0006', 'Glass Cleaner 500ml', 'pcs', 450, 40),
    _product(7, 'SKU-0007', 'Toilet Cleaner 500ml', 'pcs', 395, 70),
  ];

  static final List<Map<String, dynamic>> _orders = [
    _order(
      1042,
      1,
      'pending',
      DateTime.now().subtract(const Duration(hours: 2)),
      [(1, 6), (3, 4)],
    ),
    _order(
      1041,
      3,
      'pending',
      DateTime.now().subtract(const Duration(hours: 20)),
      [(4, 10), (5, 5), (2, 8)],
    ),
    _order(
      1040,
      2,
      'completed',
      DateTime.now().subtract(const Duration(days: 2)),
      [(2, 3)],
    ),
    _order(
      1039,
      4,
      'cancelled',
      DateTime.now().subtract(const Duration(days: 3)),
      [(6, 5)],
    ),
    _order(
      1038,
      5,
      'completed',
      DateTime.now().subtract(const Duration(days: 5)),
      [(1, 24), (7, 12)],
    ),
  ];

  static int _nextOrderId = 1043;
  static int _nextProductId = 100;

  static Map<String, dynamic> _customer(
    int id,
    String name,
    String phone,
    String address,
    double balance,
    double limit,
  ) => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': null,
    'address': address,
    'customer_category_id': 1,
    'category': {'id': 1, 'name': 'Retail'},
    'credit_limit': limit,
    'current_balance': balance,
    'is_active': true,
  };

  static Map<String, dynamic> _product(
    int id,
    String sku,
    String name,
    String unit,
    double price,
    int stock,
  ) => {
    'id': id,
    'sku': sku,
    'name': name,
    'unit': unit,
    'selling_price': price,
    'stock_quantity': stock,
    'image_url': null,
    'category': {'id': 1, 'name': 'Cleaning'},
  };

  static Map<String, dynamic> _order(
    int id,
    int customerId,
    String status,
    DateTime date,
    List<(int, int)> lines, {
    String? notes,
  }) {
    final items = <Map<String, dynamic>>[];
    double total = 0;
    for (final (productId, qty) in lines) {
      final p = _products.firstWhere((e) => e['id'] == productId);
      final price = (p['selling_price'] as num).toDouble();
      total += price * qty;
      items.add({
        'product_id': productId,
        'product': {'id': productId, 'name': p['name']},
        'quantity': qty,
        'unit_price': price,
        'discount_percent': 0,
        'discounted_price': price,
        'line_total': price * qty,
      });
    }
    return {
      'id': id,
      'invoice_number': '$id',
      'status': status,
      'customer_id': customerId,
      'payment_type': 'credit',
      'payment_reference': null,
      'subtotal': total,
      'return_amount': 0,
      'total_amount': total,
      'sale_date': date.toIso8601String(),
      'notes': notes,
      'items': items,
      'returns': [],
      'user': {'name': 'Demo User'},
    };
  }

  static Map<String, dynamic> _customerOf(int id) => _customers.firstWhere(
    (c) => c['id'] == id,
    orElse: () => _customers.first,
  );

  static Map<String, dynamic> _withCustomer(Map<String, dynamic> order) => {
    ...order,
    'customer': _customerOf(order['customer_id'] as int),
  };

  static Future<dynamic> handle(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));

    // ---- orders ----
    if (path == '/sales' && method == 'GET') {
      final term = (query?['search'] ?? '').toLowerCase();
      final list = _orders.map(_withCustomer).where((o) {
        if (term.isEmpty) return true;
        final name = (o['customer']['name'] as String).toLowerCase();
        return name.contains(term) ||
            (o['invoice_number'] as String).contains(term);
      }).toList();
      return {'data': list};
    }
    if (path == '/sales' && method == 'POST') {
      final order = _buildOrder(_nextOrderId++, body!, status: 'pending');
      _orders.insert(0, order);
      return _withCustomer(order);
    }
    final saleMatch = RegExp(r'^/sales/(\d+)(/cancel)?$').firstMatch(path);
    if (saleMatch != null) {
      final id = int.parse(saleMatch.group(1)!);
      final index = _orders.indexWhere((o) => o['id'] == id);
      if (index < 0) throw ApiException(404, 'Order not found.');
      final order = _orders[index];

      if (saleMatch.group(2) != null) {
        if (order['status'] == 'cancelled')
          throw ApiException(422, 'This order is already cancelled.');
        _orders[index] = {...order, 'status': 'cancelled'};
        return _withCustomer(_orders[index]);
      }
      if (method == 'PUT') {
        if (order['status'] != 'pending')
          throw ApiException(422, 'Only a pending order can be edited.');
        final rebuilt = _buildOrder(
          id,
          {...body!, 'customer_id': order['customer_id']},
          status: 'pending',
          date: order['sale_date'],
        );
        _orders[index] = rebuilt;
        return _withCustomer(rebuilt);
      }
      return _withCustomer(order);
    }

    // ---- catalog ----
    if (path == '/products' && method == 'GET') return {'data': _products};
    if (path == '/products' && method == 'POST') {
      final p = _product(
        _nextProductId++,
        'SKU-NEW${_nextProductId}',
        body!['name'] as String,
        (body['unit'] as String?) ?? 'pcs',
        (body['selling_price'] as num).toDouble(),
        (body['stock_quantity'] as num?)?.toInt() ?? 0,
      );
      _products.add(p);
      return p;
    }
    if (path == '/categories') {
      return {
        'data': [
          {'id': 1, 'name': 'Cleaning'},
          {'id': 2, 'name': 'Laundry'},
        ],
      };
    }

    // ---- customers ----
    if (path == '/customers' && method == 'GET') return {'data': _customers};
    if (path == '/customers' && method == 'POST') {
      final c = _customer(
        _customers.length + 100,
        body!['name'] as String,
        (body['phone'] as String?) ?? '',
        (body['address'] as String?) ?? '',
        0,
        (body['credit_limit'] as num?)?.toDouble() ?? 0,
      );
      _customers.add(c);
      return c;
    }
    if (path == '/customer-categories') {
      return [
        {'id': 1, 'name': 'Retail', 'parent_id': null, 'children': []},
        {'id': 2, 'name': 'Wholesale', 'parent_id': null, 'children': []},
      ];
    }
    if (RegExp(r'^/customers/\d+/(ledger|returnable-items)$').hasMatch(path))
      return {'data': []};

    // ---- misc ----
    if (path == '/shop-settings') {
      return {
        'name': 'Kleen Spirit Lanka',
        'address': 'Colombo, Sri Lanka',
        'phone': '0112345678',
        'company_phone': '',
        'tax_id': '',
        'footer_note': 'Thank you!',
        'paper_size': 'mm58',
        'receipt_language': 'en',
      };
    }

    return method == 'GET' ? {'data': []} : <String, dynamic>{};
  }

  static Map<String, dynamic> _buildOrder(
    int id,
    Map<String, dynamic> body, {
    required String status,
    dynamic date,
  }) {
    final lines = <(int, int)>[
      for (final item in body['items'] as List)
        (
          (item['product_id'] as num).toInt(),
          (item['quantity'] as num).toInt(),
        ),
    ];
    final order = _order(
      id,
      (body['customer_id'] as num).toInt(),
      status,
      date is String ? DateTime.parse(date) : DateTime.now(),
      lines,
      notes: (body['notes'] as String?)?.isEmpty == true
          ? null
          : body['notes'] as String?,
    );
    return order;
  }
}
