import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer_category.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/customer_service.dart';
import '../theme.dart';

class NewCustomerScreen extends StatefulWidget {
  const NewCustomerScreen({super.key});

  @override
  State<NewCustomerScreen> createState() => _NewCustomerScreenState();
}

class _NewCustomerScreenState extends State<NewCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  late final CustomerService _customerService;
  List<CustomerCategory> _categories = [];
  CustomerCategory? _selectedTopLevel;
  CustomerCategory? _selectedSubcategory;
  bool _isSubmitting = false;
  String? _error;

  /// The category actually assigned to the customer: the subcategory if one
  /// was picked, otherwise the top-level category itself.
  CustomerCategory? get _effectiveCategory =>
      _selectedSubcategory ?? _selectedTopLevel;

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService(context.read<AuthProvider>().api);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _customerService.categories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Categories are optional on this form — silently skip if unavailable.
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _customerService.create(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        categoryId: _effectiveCategory?.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Customer created.')));
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not connect to server.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Customer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  label: RequiredLabel('Name'),
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  prefixIcon: Icon(Icons.phone_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
              ),
              if (_categories.isNotEmpty) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<CustomerCategory>(
                  initialValue: _selectedTopLevel,
                  decoration: const InputDecoration(
                    labelText: 'Category (optional)',
                    prefixIcon: Icon(Icons.sell_outlined, size: 20),
                  ),
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (c) => setState(() {
                    _selectedTopLevel = c;
                    // Switching the top-level category invalidates whatever
                    // subcategory was picked under the old one.
                    _selectedSubcategory = null;
                  }),
                ),
                if (_selectedTopLevel != null &&
                    _selectedTopLevel!.children.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<CustomerCategory?>(
                    initialValue: _selectedSubcategory,
                    decoration: const InputDecoration(
                      labelText: 'Subcategory (optional)',
                      prefixIcon: Icon(
                        Icons.subdirectory_arrow_right_rounded,
                        size: 20,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('General (no subcategory)'),
                      ),
                      ..._selectedTopLevel!.children.map(
                        (sc) =>
                            DropdownMenuItem(value: sc, child: Text(sc.name)),
                      ),
                    ],
                    onChanged: (c) => setState(() => _selectedSubcategory = c),
                  ),
                ],
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.criticalSoft,
                    borderRadius: BorderRadius.circular(10),
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
                          _error!,
                          style: const TextStyle(
                            color: AppColors.critical,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Customer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
