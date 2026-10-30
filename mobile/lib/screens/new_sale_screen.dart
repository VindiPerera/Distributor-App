import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/customer_category.dart';
import '../models/product.dart';
import '../models/receipt_data.dart';
import '../models/returnable_sale.dart';
import '../models/sale.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/customer_service.dart';
import '../services/product_service.dart';
import '../services/sale_service.dart';
import '../theme.dart';
import 'receipt_preview_screen.dart';

/// Which unit the per-line discount value is entered in.
enum DiscountMode { percent, amount }

class _CartLine {
  final Product product;
  int quantity;

  /// Per-line discount, entered at billing time either as a percentage
  /// (0-100) or a flat Rs. amount off the unit price — [discountMode] says
  /// which one [discountController]'s text means. New lines always start
  /// in percent mode; the cashier switches via [setMode] if needed.
  final TextEditingController discountController;
  DiscountMode discountMode = DiscountMode.percent;

  _CartLine(this.product, this.quantity, {double discountPercent = 0})
    : discountController = TextEditingController(
        text: discountPercent > 0 ? _trimZeros(discountPercent) : '',
      );

  static String _trimZeros(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double get _rawValue {
    final raw = double.tryParse(discountController.text) ?? 0;
    return raw < 0 ? 0 : raw;
  }

  double get discountPercent {
    if (discountMode != DiscountMode.percent) return 0;
    final raw = _rawValue;
    return raw > 100 ? 100 : raw;
  }

  double get discountAmount {
    if (discountMode != DiscountMode.amount) return 0;
    final raw = _rawValue;
    return raw > product.sellingPrice ? product.sellingPrice : raw;
  }

  double get discountedPrice {
    if (discountMode == DiscountMode.amount) {
      return product.sellingPrice - discountAmount;
    }
    return product.sellingPrice * (1 - discountPercent / 100);
  }

  double get lineTotal => discountedPrice * quantity;

  /// Switching modes clears the entered value rather than converting it —
  /// a "20" typed as % doesn't mean anything sensible reinterpreted as Rs.
  void setMode(DiscountMode mode) {
    if (mode == discountMode) return;
    discountMode = mode;
    discountController.clear();
  }

  void dispose() => discountController.dispose();
}

const _paymentTypeOptions = [
  (value: 'cash', label: 'Cash', icon: Icons.payments_outlined),
  (value: 'credit', label: 'Credit', icon: Icons.receipt_long_outlined),
  (value: 'cheque', label: 'Cheque', icon: Icons.request_quote_outlined),
];

const _settlementMethodOptions = [
  (value: 'cash', label: 'Cash', icon: Icons.payments_outlined),
];

class NewSaleScreen extends StatefulWidget {
  /// When set, the screen opens in "settle credit" mode for this customer
  /// instead of the normal product/cart sale flow: the cart is replaced by
  /// a single fixed line for the outstanding balance, and completing it
  /// records a payment (not a sale) before showing a receipt.
  final Customer? settlementCustomer;

  const NewSaleScreen({super.key, this.settlementCustomer});

  bool get isSettlement => settlementCustomer != null;

  @override
  State<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends State<NewSaleScreen> {
  late final ProductService _productService;
  late final CustomerService _customerService;
  late final SaleService _saleService;

  List<Product> _products = [];
  List<Customer> _customers = [];
  List<CustomerCategory> _categories = [];
  CustomerCategory? _categoryFilter;
  List<ProductCategory> _productCategoryOptions = [];
  final Map<int, _CartLine> _cart = {};

  // Products the selected customer bought earlier and can still return.
  // Keyed by sale_item_id -> how many of that line the cashier has picked
  // to return on this bill (0 < qty <= that item's returnableQuantity).
  List<ReturnableSale> _returnableSales = [];
  final Map<int, int> _selectedReturns = {};
  bool _isLoadingReturns = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _productCategoryFilter;

  final TextEditingController _paidAmountController = TextEditingController();
  final TextEditingController _paymentReferenceController =
      TextEditingController();

  String _paymentType = 'cash';
  Customer? _selectedCustomer;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  late final TextEditingController _settlementAmountController;
  final String _settlementMethod = 'cash';

  bool get _isSettlement => widget.isSettlement;

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().api;
    _productService = ProductService(api);
    _customerService = CustomerService(api);
    _saleService = SaleService(api);
    _settlementAmountController = TextEditingController(
      text: _isSettlement
          ? widget.settlementCustomer!.currentBalance.toStringAsFixed(2)
          : '',
    );
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paidAmountController.dispose();
    _paymentReferenceController.dispose();
    _settlementAmountController.dispose();
    for (final line in _cart.values) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_isSettlement) {
      setState(() {
        _selectedCustomer = widget.settlementCustomer;
        _isLoading = false;
      });
      return;
    }
    final products = await _productService.list();
    final customers = await _customerService.list();
    List<CustomerCategory> categories = [];
    try {
      categories = await _customerService.categories();
    } catch (_) {
      // Category filter is optional — skip silently if unavailable.
    }
    List<ProductCategory> productCategories = [];
    try {
      productCategories = await _productService.categories();
    } catch (_) {
      // Only needed for the quick-add-product dialog — skip silently if unavailable.
    }
    setState(() {
      _products = products;
      _customers = customers;
      _categories = categories;
      _productCategoryOptions = productCategories;
      _isLoading = false;
    });
  }

  void _addToCart(Product product) {
    setState(() {
      final existing = _cart[product.id];
      if (existing != null) {
        existing.quantity++;
      } else {
        _cart[product.id] = _CartLine(product, 1);
      }
    });
  }

  void _updateQuantity(int productId, int delta) {
    setState(() {
      final line = _cart[productId];
      if (line == null) return;
      final newQty = line.quantity + delta;
      if (newQty <= 0) {
        line.dispose();
        _cart.remove(productId);
      } else {
        line.quantity = newQty;
      }
    });
  }

  /// Lets the rep add a product that isn't in the catalog yet, right from
  /// the order screen, and drops it straight into the cart so the store's
  /// order doesn't have to wait on someone updating the catalog first.
  Future<void> _quickAddProduct() async {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '1');
    ProductCategory? selectedCategory;
    String? formError;
    bool isSaving = false;

    final created = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> submit() async {
              final name = nameController.text.trim();
              final price = double.tryParse(priceController.text.trim());
              final stock = int.tryParse(stockController.text.trim()) ?? 0;

              if (name.isEmpty) {
                setSheetState(() => formError = 'Enter a product name.');
                return;
              }
              if (price == null || price <= 0) {
                setSheetState(() => formError = 'Enter a valid selling price.');
                return;
              }

              setSheetState(() {
                formError = null;
                isSaving = true;
              });
              try {
                final product = await _productService.create(
                  name: name,
                  sellingPrice: price,
                  categoryId: selectedCategory?.id,
                  stockQuantity: stock < 0 ? 0 : stock,
                );
                if (sheetContext.mounted) Navigator.pop(sheetContext, product);
              } on ApiException catch (e) {
                setSheetState(() {
                  formError = e.message;
                  isSaving = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add New Product',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Not in the catalog yet? Add it here and it\'ll drop straight into this order.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        label: RequiredLabel('Product Name'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        label: RequiredLabel('Selling Price'),
                        prefixText: 'Rs. ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Initial Stock Quantity',
                        helperText: 'How many units the store is taking now',
                      ),
                    ),
                    if (_productCategoryOptions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<ProductCategory>(
                        initialValue: selectedCategory,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category (optional)',
                        ),
                        items: [
                          const DropdownMenuItem<ProductCategory>(
                            value: null,
                            child: Text('Uncategorized'),
                          ),
                          ..._productCategoryOptions.map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          ),
                        ],
                        onChanged: (c) =>
                            setSheetState(() => selectedCategory = c),
                      ),
                    ],
                    if (formError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.criticalSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          formError!,
                          style: const TextStyle(
                            color: AppColors.critical,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSaving ? null : submit,
                        child: isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Add Product'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    priceController.dispose();
    stockController.dispose();

    if (created == null || !mounted) return;
    setState(() {
      _products = [..._products, created]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    _addToCart(created);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${created.name} added to the catalog and to this order.',
        ),
      ),
    );
  }

  double get _settlementAmount =>
      double.tryParse(_settlementAmountController.text) ?? 0;

  double get _subtotal => _isSettlement
      ? _settlementAmount
      : _cart.values.fold(0, (sum, line) => sum + line.lineTotal);
  int get _itemCount => _isSettlement
      ? (_settlementAmount > 0 ? 1 : 0)
      : _cart.values.fold(0, (sum, line) => sum + line.quantity);

  /// All returnable items across every one of the customer's past sales,
  /// flattened, keyed by sale_item_id — convenient for looking up a
  /// selected return's unit price/product name without re-searching
  /// _returnableSales every time.
  Map<int, ReturnableItem> get _returnableItemsById {
    final map = <int, ReturnableItem>{};
    for (final sale in _returnableSales) {
      for (final item in sale.items) {
        map[item.saleItemId] = item;
      }
    }
    return map;
  }

  double get _returnsTotal {
    if (_selectedReturns.isEmpty) return 0;
    final byId = _returnableItemsById;
    return _selectedReturns.entries.fold(0.0, (sum, e) {
      final item = byId[e.key];
      if (item == null) return sum;
      return sum + item.unitPrice * e.value;
    });
  }

  /// Product being returned from an earlier purchase gets its price
  /// deducted straight off this bill's total.
  double get _total => (_subtotal - _returnsTotal).clamp(0, double.infinity);

  Future<void> _loadReturnableItems(int customerId) async {
    setState(() {
      _isLoadingReturns = true;
      _returnableSales = [];
      _selectedReturns.clear();
    });
    try {
      final sales = await _customerService.returnableItems(customerId);
      if (mounted) setState(() => _returnableSales = sales);
    } catch (_) {
      // Returns are optional at checkout — skip silently if unavailable.
    } finally {
      if (mounted) setState(() => _isLoadingReturns = false);
    }
  }

  void _setReturnQuantity(ReturnableItem item, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _selectedReturns.remove(item.saleItemId);
      } else {
        _selectedReturns[item.saleItemId] = quantity > item.returnableQuantity
            ? item.returnableQuantity
            : quantity;
      }
    });
  }

  /// Credit sales are never paid up front (the whole total becomes the
  /// customer's balance). Cash sales are normally paid in full, but the
  /// cashier can enter a smaller amount if the customer only pays part now.
  bool get _allowsPartialPayment => _paymentType == 'cash';

  /// Amount the customer actually handed over right now. Defaults to the
  /// full total when the field is blank (untouched) so a normal, fully-paid
  /// sale doesn't require the cashier to type anything.
  double get _paidAmount {
    if (!_allowsPartialPayment) return 0;
    final text = _paidAmountController.text.trim();
    if (text.isEmpty) return _total;
    final parsed = double.tryParse(text) ?? _total;
    return parsed < 0 ? 0 : (parsed > _total ? _total : parsed);
  }

  /// Unpaid portion of this sale, tracked on the customer's account balance.
  double get _balanceDue => _paymentType == 'credit'
      ? _total
      : ((_total - _paidAmount) * 100).round() / 100;

  /// Distinct product categories present in the loaded catalog, sorted by
  /// name. Derived from the products themselves (each already carries its
  /// category via the `/products` response) instead of a separate API call.
  List<({int id, String name})> get _productCategories {
    final seen = <int, String>{};
    for (final p in _products) {
      if (p.categoryId != null && p.categoryName != null) {
        seen[p.categoryId!] = p.categoryName!;
      }
    }
    final entries = seen.entries
        .map((e) => (id: e.key, name: e.value))
        .toList();
    entries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return entries;
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _products.where((p) {
      final matchesQuery =
          query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.sku.toLowerCase().contains(query);
      final matchesCategory =
          _productCategoryFilter == null ||
          p.categoryId == _productCategoryFilter;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  List<Customer> _filterCustomers(String query, {CustomerCategory? category}) {
    final q = query.trim().toLowerCase();
    // Matching a top-level category also matches any of its subcategories,
    // so picking "Retail" (say) surfaces customers assigned directly to
    // "Retail" as well as ones assigned to "Retail > Wholesale" etc.
    final matchingIds = category == null
        ? null
        : {category.id, ...category.children.map((c) => c.id)};
    return _customers.where((c) {
      final matchesQuery =
          q.isEmpty ||
          c.name.toLowerCase().contains(q) ||
          (c.phone ?? '').toLowerCase().contains(q);
      final matchesCategory =
          matchingIds == null || matchingIds.contains(c.categoryId);
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Widget _productPlaceholder() {
    return Container(
      width: 44,
      height: 44,
      color: AppColors.lineSoft,
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 20,
        color: AppColors.inkSoft,
      ),
    );
  }

  Future<void> _pickCustomer() async {
    final searchController = TextEditingController();
    CustomerCategory? sheetCategoryFilter = _categoryFilter;
    // Narrows further within sheetCategoryFilter's subcategories, if it has
    // any. Filtering by this (when set) takes over from the top-level one.
    CustomerCategory? sheetSubcategoryFilter;
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final query = searchController.text;
            final results = _filterCustomers(
              query,
              category: sheetSubcategoryFilter ?? sheetCategoryFilter,
            );
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select Customer',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name or phone',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () => setSheetState(
                                    () => searchController.clear(),
                                  ),
                                ),
                        ),
                      ),
                    ),
                    if (_categories.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _CategoryChip(
                              label: 'All',
                              selected: sheetCategoryFilter == null,
                              onTap: () => setSheetState(() {
                                sheetCategoryFilter = null;
                                sheetSubcategoryFilter = null;
                                _categoryFilter = null;
                              }),
                            ),
                            const SizedBox(width: 8),
                            for (final cat in _categories) ...[
                              _CategoryChip(
                                label: cat.name,
                                selected: sheetCategoryFilter?.id == cat.id,
                                onTap: () => setSheetState(() {
                                  sheetCategoryFilter = cat;
                                  sheetSubcategoryFilter = null;
                                  _categoryFilter = cat;
                                }),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (sheetCategoryFilter != null &&
                        sheetCategoryFilter!.children.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 30,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _CategoryChip(
                              label: 'All ${sheetCategoryFilter!.name}',
                              selected: sheetSubcategoryFilter == null,
                              onTap: () => setSheetState(
                                () => sheetSubcategoryFilter = null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            for (final sub
                                in sheetCategoryFilter!.children) ...[
                              _CategoryChip(
                                label: sub.name,
                                selected: sheetSubcategoryFilter?.id == sub.id,
                                onTap: () => setSheetState(
                                  () => sheetSubcategoryFilter = sub,
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(
                              child: Text(
                                'No customers match your search.',
                                style: TextStyle(color: AppColors.inkSoft),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: results.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final c = results[i];
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      c.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (c.phone != null &&
                                            c.phone!.isNotEmpty)
                                          c.phone!,
                                        if (c.categoryName != null)
                                          c.categoryName!,
                                        if (c.currentBalance > 0)
                                          'Owes Rs. ${c.currentBalance.toStringAsFixed(0)}',
                                      ].join('  ·  '),
                                    ),
                                    onTap: () => Navigator.pop(sheetContext, c),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    searchController.dispose();
    if (picked != null) {
      setState(() => _selectedCustomer = picked);
      _loadReturnableItems(picked.id);
    }
  }

  /// Bottom sheet listing the selected customer's past sales and, under
  /// each, the line items that still have quantity left to return. Picking
  /// a quantity for an item adds/updates it in [_selectedReturns].
  Future<void> _pickReturnItem(BuildContext context) async {
    if (_returnableSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This customer has no past purchases available to return.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SizedBox(
                height: MediaQuery.of(sheetContext).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Return a Product',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _returnableSales.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, i) {
                          final sale = _returnableSales[i];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invoice ${sale.invoiceNumber}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...sale.items.map((item) {
                                final selectedQty =
                                    _selectedReturns[item.saleItemId] ?? 0;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.productName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Rs. ${item.unitPrice.toStringAsFixed(2)} each  ·  ${item.returnableQuantity} returnable',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.inkSoft,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _QtyStepper(
                                          quantity: selectedQty,
                                          onDecrement: () {
                                            _setReturnQuantity(
                                              item,
                                              selectedQty - 1,
                                            );
                                            setSheetState(() {});
                                          },
                                          onIncrement: () {
                                            if (selectedQty >=
                                                item.returnableQuantity)
                                              return;
                                            _setReturnQuantity(
                                              item,
                                              selectedQty + 1,
                                            );
                                            setSheetState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSettleCredit(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewSaleScreen(settlementCustomer: customer),
      ),
    );
    final customers = await _customerService.list();
    if (mounted) {
      setState(() {
        _customers = customers;
        _selectedCustomer = customers.firstWhere(
          (c) => c.id == customer.id,
          orElse: () => customer,
        );
      });
    }
  }

  Future<void> _openCheckout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _CheckoutScreen(state: this)),
    );
  }

  Future<void> _submitSale() {
    return _isSettlement ? _submitSettlement() : _submitRegularSale();
  }

  Future<void> _submitRegularSale() async {
    if (_cart.isEmpty) {
      setState(() => _error = 'Add at least one item.');
      return;
    }
    if (_selectedCustomer == null) {
      setState(() => _error = 'Select a customer to issue the bill.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _saleService.createSale(
        customerId: _selectedCustomer!.id,
        paymentType: _paymentType,
        paymentReference: _paymentReferenceController.text.trim(),
        paidAmount: _allowsPartialPayment ? _paidAmount : null,
        items: _cart.values
            .map(
              (l) => SaleItemInput(
                productId: l.product.id,
                quantity: l.quantity,
                discountType: l.discountMode == DiscountMode.amount
                    ? 'amount'
                    : 'percent',
                discountPercent: l.discountPercent,
                discountAmount: l.discountAmount,
              ),
            )
            .toList(),
        returns: _selectedReturns.entries
            .map((e) => ReturnInput(saleItemId: e.key, quantity: e.value))
            .toList(),
      );
      if (!mounted) return;
      final sale = Sale.fromJson(result);
      final cashierName =
          context.read<AuthProvider>().currentUser?['name'] as String? ?? '-';
      final returnsById = _returnableItemsById;

      final receipt = ReceiptData(
        invoiceNumber: sale.invoiceNumber,
        // sale.saleDate is UTC from the API — show the device's local
        // (Sri Lanka) time on the receipt instead of the raw UTC clock time.
        date: sale.saleDate.toLocal(),
        lines: _cart.values
            .map(
              (l) => ReceiptLine(
                name: l.product.name,
                quantity: l.quantity,
                unitPrice: l.product.sellingPrice,
                discountedPrice: l.discountedPrice,
                lineTotal: l.lineTotal,
              ),
            )
            .toList(),
        subtotal: _subtotal,
        returns: _selectedReturns.entries
            .where((e) => returnsById.containsKey(e.key))
            .map(
              (e) => ReceiptReturn(
                name: returnsById[e.key]!.productName,
                quantity: e.value,
                amount: returnsById[e.key]!.unitPrice * e.value,
              ),
            )
            .toList(),
        total: _total,
        paymentType: _paymentType,
        customerName: _selectedCustomer?.name,
        customerPhone: _selectedCustomer?.phone,
        cashierName: cashierName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale recorded successfully.')),
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptPreviewScreen(receipt: receipt),
          ),
        );
        if (mounted) {
          // Submission always happens from the checkout page pushed on top
          // of this screen — closing the receipt should land back on the
          // product browser, past both the checkout page and this one.
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitSettlement() async {
    final customer = widget.settlementCustomer!;
    final amount = _settlementAmount;

    if (amount <= 0) {
      setState(() => _error = 'Enter an amount to settle.');
      return;
    }
    if (amount > customer.currentBalance) {
      setState(
        () => _error =
            'Amount cannot exceed the outstanding balance of Rs. ${customer.currentBalance.toStringAsFixed(2)}.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final result = await _customerService.recordPayment(
        customerId: customer.id,
        amount: amount,
        method: _settlementMethod,
      );
      if (!mounted) return;
      final cashierName =
          context.read<AuthProvider>().currentUser?['name'] as String? ?? '-';
      final paymentId = result['id'];
      final paidAt = result['paid_at'] != null
          ? DateTime.tryParse(result['paid_at'] as String)
          : null;

      final receipt = ReceiptData(
        invoiceNumber: 'PMT-$paymentId',
        date: paidAt ?? DateTime.now(),
        lines: [
          ReceiptLine(
            name: 'Credit Settlement',
            quantity: 1,
            unitPrice: amount,
            discountedPrice: amount,
            lineTotal: amount,
          ),
        ],
        subtotal: amount,
        total: amount,
        paymentType: 'credit_settlement',
        customerName: customer.name,
        customerPhone: customer.phone,
        cashierName: cashierName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded successfully.')),
        );
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptPreviewScreen(receipt: receipt),
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSettlement
              ? 'Settle Credit — ${widget.settlementCustomer!.name}'
              : 'New Sale',
        ),
        actions: [
          if (!_isSettlement)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined),
                  tooltip: 'View cart',
                  onPressed: _openCheckout,
                ),
                if (_itemCount > 0)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_itemCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isSettlement ? _buildSettlementBody() : _buildProductBrowser(),
    );
  }

  Widget _buildProductBrowser() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search products by name or SKU',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            }),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.add_box_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: 'Add new product',
                  onPressed: _quickAddProduct,
                ),
              ),
            ],
          ),
        ),
        if (_productCategories.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: _productCategoryFilter == null,
                  onTap: () => setState(() => _productCategoryFilter = null),
                ),
                const SizedBox(width: 8),
                for (final cat in _productCategories) ...[
                  _CategoryChip(
                    label: cat.name,
                    selected: _productCategoryFilter == cat.id,
                    onTap: () =>
                        setState(() => _productCategoryFilter = cat.id),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
        Expanded(
          child: _products.isEmpty
              ? const Center(
                  child: Text(
                    'No products available.',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                )
              : _filteredProducts.isEmpty
              ? const Center(
                  child: Text(
                    'No products match your filters.',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredProducts.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = _filteredProducts[i];
                    final inCart = _cart.containsKey(p.id);
                    final lowStock = p.stockQuantity <= 0;

                    return Card(
                      color: inCart ? AppColors.accentSoft : AppColors.surface,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: lowStock ? null : () => _addToCart(p),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: p.imageUrl != null
                                    ? Image.network(
                                        p.imageUrl!,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                _productPlaceholder(),
                                      )
                                    : _productPlaceholder(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Rs. ${p.sellingPrice.toStringAsFixed(2)}  ·  Stock: ${p.stockQuantity}',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: lowStock
                                            ? AppColors.critical
                                            : AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (inCart) ...[
                                _QtyStepper(
                                  quantity: _cart[p.id]!.quantity,
                                  onDecrement: () => _updateQuantity(p.id, -1),
                                  onIncrement: () => _updateQuantity(p.id, 1),
                                ),
                              ] else
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: lowStock
                                        ? AppColors.lineSoft
                                        : AppColors.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: Icon(
                                      Icons.add_rounded,
                                      size: 20,
                                      color: lowStock
                                          ? AppColors.inkSoft
                                          : Colors.white,
                                    ),
                                    onPressed: lowStock
                                        ? null
                                        : () => _addToCart(p),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (_itemCount > 0)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _openCheckout,
                  icon: const Icon(
                    Icons.shopping_cart_checkout_rounded,
                    size: 20,
                  ),
                  label: Text(
                    'View Cart · $_itemCount item${_itemCount == 1 ? '' : 's'} · Rs. ${_total.toStringAsFixed(2)}',
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSettlementBody() {
    final customer = widget.settlementCustomer!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warnSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Outstanding balance: Rs. ${customer.currentBalance.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Amount to settle',
            style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _settlementAmountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixText: 'Rs. '),
          ),
          const SizedBox(height: 20),
          const Text(
            'Payment method',
            style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: _settlementMethodOptions
                .map(
                  (o) => ButtonSegment(
                    value: o.value,
                    label: Text(o.label),
                    icon: Icon(o.icon, size: 16),
                  ),
                )
                .toList(),
            selected: {_settlementMethod},
            onSelectionChanged: (s) {},
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.criticalSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.critical, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
              Text(
                'Rs. ${_settlementAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitSale,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Complete Settlement'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Checkout page: cart lines, payment type, customer, and totals. Kept as a
/// separate page (reached via the cart icon on [NewSaleScreen]) so the
/// product browser always has full screen space to search/add items — the
/// checkout form previously lived in a fixed-height panel docked under the
/// product list, which could overflow and squeeze the product list down to
/// nothing once enough fields/cart lines were showing.
class _CheckoutScreen extends StatefulWidget {
  final _NewSaleScreenState state;

  const _CheckoutScreen({required this.state});

  @override
  State<_CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<_CheckoutScreen> {
  _NewSaleScreenState get s => widget.state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: SafeArea(
        child: StatefulBuilder(
          builder: (context, setLocalState) {
            // Cart mutations happen on the owning NewSaleScreen's state (via
            // setState there), so this page needs its own rebuild trigger
            // too — wrapping the whole body lets every control here refresh
            // immediately without lifting more state up.
            void refresh() => setLocalState(() {});

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (s._cart.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Your cart is empty.',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      ),
                    )
                  else ...[
                    Row(
                      children: const [
                        Expanded(
                          flex: 4,
                          child: Text(
                            'Product',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 84,
                          child: Text(
                            'Discount',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Price',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        SizedBox(
                          width: 66,
                          child: Text(
                            'Total',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...s._cart.values.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    line.product.name,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  _QtyStepper(
                                    quantity: line.quantity,
                                    onDecrement: () {
                                      s._updateQuantity(line.product.id, -1);
                                      refresh();
                                    },
                                    onIncrement: () {
                                      s._updateQuantity(line.product.id, 1);
                                      refresh();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 84,
                              child: Column(
                                children: [
                                  TextField(
                                    controller: line.discountController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    textAlign: TextAlign.center,
                                    onChanged: (_) => refresh(),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 8,
                                          ),
                                      hintText: '0',
                                      prefixText:
                                          line.discountMode ==
                                              DiscountMode.amount
                                          ? 'Rs. '
                                          : null,
                                      suffixText:
                                          line.discountMode ==
                                              DiscountMode.percent
                                          ? '%'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  _DiscountModeToggle(
                                    mode: line.discountMode,
                                    onChanged: (mode) {
                                      line.setMode(mode);
                                      refresh();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 60,
                              child: Text(
                                line.discountedPrice.toStringAsFixed(2),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 66,
                              child: Text(
                                'Rs. ${line.lineTotal.toStringAsFixed(2)}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 20),
                  ],
                  if (s._selectedCustomer != null) ...[
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Return a Product',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: s._isLoadingReturns
                              ? null
                              : () async {
                                  await s._pickReturnItem(context);
                                  refresh();
                                },
                          icon: const Icon(
                            Icons.assignment_return_outlined,
                            size: 16,
                          ),
                          label: const Text('Add'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                          ),
                        ),
                      ],
                    ),
                    if (s._selectedReturns.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ...s._selectedReturns.entries.map((entry) {
                        final item = s._returnableItemsById[entry.key];
                        if (item == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.productName} x${entry.value}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.ink,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '- Rs. ${(item.unitPrice * entry.value).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.critical,
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.critical,
                                ),
                                onPressed: () {
                                  s._setReturnQuantity(item, 0);
                                  refresh();
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    const Divider(height: 20),
                  ],
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<String>(
                      segments: _paymentTypeOptions
                          .map(
                            (o) => ButtonSegment(
                              value: o.value,
                              label: Text(o.label),
                              icon: Icon(o.icon, size: 16),
                            ),
                          )
                          .toList(),
                      selected: {s._paymentType},
                      onSelectionChanged: (v) {
                        setState(() => s._paymentType = v.first);
                        refresh();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await s._pickCustomer();
                            refresh();
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              label: const RequiredLabel('Customer'),
                              prefixIcon: const Icon(
                                Icons.person_search_rounded,
                                size: 20,
                              ),
                            ),
                            child: Text(
                              s._selectedCustomer == null
                                  ? 'Search customer by name or phone'
                                  : s._selectedCustomer!.phone != null &&
                                        s._selectedCustomer!.phone!.isNotEmpty
                                  ? '${s._selectedCustomer!.name}  ·  ${s._selectedCustomer!.phone}'
                                  : s._selectedCustomer!.name,
                              style: TextStyle(
                                color: s._selectedCustomer == null
                                    ? AppColors.inkSoft
                                    : AppColors.ink,
                                fontWeight: s._selectedCustomer == null
                                    ? FontWeight.w400
                                    : FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      if (s._selectedCustomer != null &&
                          s._selectedCustomer!.currentBalance > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          height: 56,
                          width: 44,
                          decoration: BoxDecoration(
                            color: AppColors.goodSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.payments_outlined,
                              size: 19,
                              color: AppColors.good,
                            ),
                            tooltip: 'Settle credit',
                            onPressed: () async {
                              await s._openSettleCredit(s._selectedCustomer!);
                              refresh();
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (s._allowsPartialPayment) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Customer Paid',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: s._paidAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) => refresh(),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              hintText: s._total.toStringAsFixed(2),
                              prefixText: 'Rs. ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (s._balanceDue > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Rs. ${s._balanceDue.toStringAsFixed(2)} will be added to ${s._selectedCustomer?.name ?? 'the customer\'s'} balance.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.warn,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                  if (s._error != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.criticalSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        s._error!,
                        style: const TextStyle(
                          color: AppColors.critical,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  if (s._selectedReturns.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        Text(
                          'Rs. ${s._subtotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Returns',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.critical,
                          ),
                        ),
                        Text(
                          '- Rs. ${s._returnsTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.critical,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      Text(
                        'Rs. ${s._total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                  if (s._paymentType == 'credit') ...[
                    const SizedBox(height: 4),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Balance due',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.warn,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Full amount',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.warn,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ] else if (s._allowsPartialPayment && s._balanceDue > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Paid now',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        Text(
                          'Rs. ${s._paidAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Balance due',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.warn,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Rs. ${s._balanceDue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.warn,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: s._isSubmitting || s._cart.isEmpty
                          ? null
                          : () async {
                              await s._submitSale();
                              refresh();
                            },
                      child: s._isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Complete Sale'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact two-way switch for a cart line's discount input: percentage off
/// vs. a flat Rs. amount off. Segmented rather than a dropdown since there
/// are only ever two choices and this needs to be legible at a small size
/// next to the numeric field it controls.
class _DiscountModeToggle extends StatelessWidget {
  final DiscountMode mode;
  final ValueChanged<DiscountMode> onChanged;

  const _DiscountModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        color: AppColors.lineSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('%', DiscountMode.percent),
          _segment('Rs.', DiscountMode.amount),
        ],
      ),
    );
  }

  Widget _segment(String label, DiscountMode value) {
    final selected = mode == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QtyStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lineSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove_rounded, onDecrement),
          SizedBox(
            width: 24,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          _stepBtn(Icons.add_rounded, onIncrement),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 15, color: AppColors.inkSoft),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.lineSoft,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}
