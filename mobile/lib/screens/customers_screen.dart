import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../providers/auth_provider.dart';
import '../services/customer_service.dart';
import '../theme.dart';
import 'customer_detail_screen.dart';
import 'new_customer_screen.dart';
import 'new_sale_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late final CustomerService _customerService;
  late Future<List<Customer>> _future;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService(context.read<AuthProvider>().api);
    _future = _customerService.list();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = _customerService.list());
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return customers;
    return customers
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.phone ?? '').toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _openNewCustomer() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewCustomerScreen()),
    );
    if (created == true) _reload();
  }

  Future<void> _openCustomerDetail(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customer: customer),
      ),
    );
    _reload();
  }

  Future<void> _openSettleCredit(Customer customer) async {
    if (customer.currentBalance <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This customer has no outstanding balance.'),
        ),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewSaleScreen(settlementCustomer: customer),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customers')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openNewCustomer,
        tooltip: 'New Customer',
        child: const Icon(Icons.person_add_alt_1_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search customers by name or phone',
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
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final allCustomers = snapshot.data ?? [];
                if (allCustomers.isEmpty) {
                  return const Center(
                    child: Text(
                      'No customers yet.',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  );
                }
                final customers = _filterCustomers(allCustomers);
                if (customers.isEmpty) {
                  return const Center(
                    child: Text(
                      'No customers match your search.',
                      style: TextStyle(color: AppColors.inkSoft),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = customers[i];
                      final hasBalance = c.currentBalance > 0;
                      final initial = c.name.isNotEmpty
                          ? c.name[0].toUpperCase()
                          : '?';

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openCustomerDetail(c),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.accentSoft,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15.5,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        hasBalance
                                            ? 'Owes Rs. ${c.currentBalance.toStringAsFixed(2)}'
                                            : 'No outstanding balance',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: hasBalance
                                              ? AppColors.warn
                                              : AppColors.inkSoft,
                                          fontWeight: hasBalance
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (hasBalance)
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: AppColors.goodSoft,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.payments_outlined,
                                        size: 19,
                                        color: AppColors.good,
                                      ),
                                      tooltip: 'Settle credit',
                                      onPressed: () => _openSettleCredit(c),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
