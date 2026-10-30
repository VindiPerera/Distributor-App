import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/product.dart';
import '../models/sale.dart';
import '../models/sale_detail.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/customer_service.dart';
import '../services/product_service.dart';
import '../services/sale_service.dart';
import '../theme.dart';

class _OrderLine {
  final Product product;
  int quantity;

  _OrderLine(this.product, this.quantity);

  double get lineTotal => product.sellingPrice * quantity;
}

/// Takes an order from a customer (no bill is issued). When [editing] is
/// given, the form is prefilled from that pending order and saving updates
/// it instead. Pops `true` once saved.
class NewOrderScreen extends StatefulWidget {
  final SaleDetail? editing;

  const NewOrderScreen({super.key, this.editing});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  late final ProductService _productService;
  late final CustomerService _customerService;
  late final SaleService _saleService;

  List<Product> _products = [];
  List<Customer> _customers = [];
  List<ProductCategory> _categories = [];
  final Map<int, _OrderLine> _lines = {};
  final _notesController = TextEditingController();

  Customer? _customer;
  bool _loading = true;
  bool _submitting = false;
  String? _loadError;
  String? _error;

  bool get _isEdit => widget.editing != null;
  double get _total => _lines.values.fold(0, (sum, l) => sum + l.lineTotal);
  int get _itemCount => _lines.values.fold(0, (sum, l) => sum + l.quantity);

  @override
  void initState() {
    super.initState();
    final api = context.read<AuthProvider>().api;
    _productService = ProductService(api);
    _customerService = CustomerService(api);
    _saleService = SaleService(api);
    _notesController.text = widget.editing?.notes ?? '';
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final products = await _productService.list();
      final customers = _isEdit ? <Customer>[] : await _customerService.list();
      List<ProductCategory> categories = [];
      try {
        categories = await _productService.categories();
      } catch (_) {
        // Only used by the create-product sheet; it works without categories.
      }

      final editing = widget.editing;
      if (editing != null) {
        final byId = {for (final p in products) p.id: p};
        for (final item in editing.items) {
          final product =
              byId[item.productId] ??
              Product(
                id: item.productId,
                sku: '',
                name: item.productName,
                unit: 'pcs',
                sellingPrice: item.unitPrice,
                stockQuantity: 0,
              );
          _lines[product.id] = _OrderLine(product, item.quantity);
        }
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _customers = customers;
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e is ApiException
            ? e.message
            : 'Could not load data. Check your connection.';
        _loading = false;
      });
    }
  }

  void _addProduct(Product product) {
    setState(() {
      final existing = _lines[product.id];
      if (existing != null) {
        existing.quantity++;
      } else {
        _lines[product.id] = _OrderLine(product, 1);
      }
    });
  }

  void _changeQty(int productId, int delta) {
    setState(() {
      final line = _lines[productId];
      if (line == null) return;
      line.quantity += delta;
      if (line.quantity <= 0) _lines.remove(productId);
    });
  }

  Future<void> _pickCustomer() async {
    final searchController = TextEditingController();
    final picked = await showModalBottomSheet<Customer>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final q = searchController.text.trim().toLowerCase();
          final results = _customers
              .where(
                (c) =>
                    c.isActive &&
                    (q.isEmpty ||
                        c.name.toLowerCase().contains(q) ||
                        (c.phone ?? '').contains(q)),
              )
              .toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.75,
              child: Column(
                children: [
                  _SheetHeader(
                    title: 'Select Customer',
                    onClose: () => Navigator.pop(sheetContext),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: searchController,
                      autofocus: true,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Search by name or phone',
                        prefixIcon: Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: results.isEmpty
                        ? const Center(
                            child: Text(
                              'No customers found.',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final c = results[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.accentSoft,
                                  child: Text(
                                    c.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  c.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: c.phone == null
                                    ? null
                                    : Text(c.phone!),
                                onTap: () => Navigator.pop(sheetContext, c),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
    if (picked != null) setState(() => _customer = picked);
  }

  Future<void> _openProductPicker() async {
    final searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final q = searchController.text.trim().toLowerCase();
          final results = _products
              .where(
                (p) =>
                    q.isEmpty ||
                    p.name.toLowerCase().contains(q) ||
                    p.sku.toLowerCase().contains(q),
              )
              .toList();
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.8,
              child: Column(
                children: [
                  _SheetHeader(
                    title: 'Add Products',
                    onClose: () => Navigator.pop(sheetContext),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            onChanged: (_) => setSheetState(() {}),
                            decoration: const InputDecoration(
                              hintText: 'Search products',
                              prefixIcon: Icon(Icons.search_rounded, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          tooltip: 'Create new product',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            minimumSize: const Size(52, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final created = await _createProduct();
                            if (created != null) setSheetState(() {});
                          },
                          icon: const Icon(
                            Icons.add_box_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'No products found.',
                                  style: TextStyle(color: AppColors.inkSoft),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    final created = await _createProduct(
                                      initialName: searchController.text.trim(),
                                    );
                                    if (created != null) setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Create new product'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final p = results[i];
                              final qty = _lines[p.id]?.quantity ?? 0;
                              return ListTile(
                                title: Text(
                                  p.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Rs. ${p.sellingPrice.toStringAsFixed(2)}  ·  ${p.stockQuantity} ${p.unit} in stock',
                                ),
                                trailing: qty > 0
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentSoft,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          '$qty added',
                                          style: const TextStyle(
                                            color: AppColors.accent,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.add_circle_outline_rounded,
                                        color: AppColors.accent,
                                      ),
                                onTap: () {
                                  _addProduct(p);
                                  setSheetState(() {});
                                },
                              );
                            },
                          ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            _itemCount == 0
                                ? 'Done'
                                : 'Done  ·  $_itemCount items',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    searchController.dispose();
  }

  /// Creates a brand-new product and adds it to this order straight away.
  Future<Product?> _createProduct({String initialName = ''}) async {
    final nameController = TextEditingController(text: initialName);
    final priceController = TextEditingController();
    final stockController = TextEditingController(text: '1');
    ProductCategory? category;
    String? formError;
    bool saving = false;

    final created = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
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
              saving = true;
            });
            try {
              final product = await _productService.create(
                name: name,
                sellingPrice: price,
                categoryId: category?.id,
                stockQuantity: stock < 0 ? 0 : stock,
              );
              if (sheetContext.mounted) Navigator.pop(sheetContext, product);
            } on ApiException catch (e) {
              setSheetState(() {
                formError = e.message;
                saving = false;
              });
            } catch (_) {
              setSheetState(() {
                formError = 'Could not create the product.';
                saving = false;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SheetHeader(
                    title: 'Create New Product',
                    onClose: () => Navigator.pop(sheetContext),
                    padded: false,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'It will be saved to the catalog and added to this order.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
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
                      labelText: 'Stock Quantity',
                    ),
                  ),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ProductCategory>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<ProductCategory>(
                          value: null,
                          child: Text('Uncategorized'),
                        ),
                        ..._categories.map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.name)),
                        ),
                      ],
                      onChanged: (c) => setSheetState(() => category = c),
                    ),
                  ],
                  if (formError != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBox(formError!),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving ? null : submit,
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create & Add to Order'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    nameController.dispose();
    priceController.dispose();
    stockController.dispose();

    if (created == null || !mounted) return null;
    setState(() {
      _products = [..._products, created]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
    _addProduct(created);
    return created;
  }

  Future<void> _submit() async {
    if (!_isEdit && _customer == null) {
      setState(() => _error = 'Select a customer first.');
      return;
    }
    if (_lines.isEmpty) {
      setState(() => _error = 'Add at least one product.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final items = _lines.values
        .map(
          (l) => SaleItemInput(productId: l.product.id, quantity: l.quantity),
        )
        .toList();
    final notes = _notesController.text.trim();

    try {
      if (_isEdit) {
        await _saleService.updateOrder(
          widget.editing!.id,
          items: items,
          notes: notes,
        );
      } else {
        await _saleService.createOrder(
          customerId: _customer!.id,
          items: items,
          notes: notes,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Order updated.' : 'Order placed.')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Could not reach the server.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Edit Order #${widget.editing!.invoiceNumber}'
              : 'New Order',
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loadError!, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    final customerName = _isEdit
        ? (widget.editing!.customerName ?? 'Customer')
        : _customer?.name;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _SectionLabel('Customer'),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppColors.softShadow,
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  onTap: _isEdit ? null : _pickCustomer,
                  leading: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  title: Text(
                    customerName ?? 'Select customer',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: customerName == null
                          ? AppColors.inkSoft
                          : AppColors.ink,
                    ),
                  ),
                  subtitle: _customer?.phone != null
                      ? Text(_customer!.phone!)
                      : null,
                  trailing: _isEdit
                      ? null
                      : const Icon(Icons.chevron_right_rounded),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: _SectionLabel('Products')),
                  TextButton.icon(
                    onPressed: _openProductPicker,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add products'),
                  ),
                ],
              ),
              if (_lines.isEmpty)
                InkWell(
                  onTap: _openProductPicker,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.line, width: 1.5),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          size: 34,
                          color: AppColors.inkSoft,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No products yet. Tap to add.',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    children: [
                      for (final line in _lines.values.toList()) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Rs. ${line.product.sellingPrice.toStringAsFixed(2)}  ·  Rs. ${line.lineTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _Stepper(
                                quantity: line.quantity,
                                onMinus: () => _changeQty(line.product.id, -1),
                                onPlus: () => _changeQty(line.product.id, 1),
                              ),
                            ],
                          ),
                        ),
                        if (line != _lines.values.last)
                          const Divider(height: 1),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              const _SectionLabel('Notes (optional)'),
              TextField(
                controller: _notesController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Delivery notes, special requests...',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _ErrorBox(_error!),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_itemCount items',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    Text(
                      'Rs. ${_total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEdit ? 'Save Changes' : 'Place Order'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;
  final bool padded;

  const _SheetHeader({
    required this.title,
    required this.onClose,
    this.padded = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padded
          ? const EdgeInsets.fromLTRB(16, 16, 8, 8)
          : const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.close_rounded), onPressed: onClose),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.criticalSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: AppColors.critical,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.critical, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _Stepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, VoidCallback onTap) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.accentSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.accent),
      ),
    );

    return Row(
      children: [
        button(
          quantity == 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
          onMinus,
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        button(Icons.add_rounded, onPlus),
      ],
    );
  }
}
