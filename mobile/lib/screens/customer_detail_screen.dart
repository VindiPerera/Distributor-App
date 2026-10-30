import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../models/customer_ledger_entry.dart';
import '../providers/auth_provider.dart';
import '../services/customer_service.dart';
import '../theme.dart';
import 'new_sale_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late final CustomerService _customerService;
  late Customer _customer;
  late Future<List<CustomerLedgerEntry>> _ledgerFuture;

  @override
  void initState() {
    super.initState();
    _customerService = CustomerService(context.read<AuthProvider>().api);
    _customer = widget.customer;
    _ledgerFuture = _customerService.ledger(_customer.id);
  }

  Future<void> _reload() async {
    final customers = await _customerService.list();
    final ledger = _customerService.ledger(_customer.id);
    if (!mounted) return;
    setState(() {
      _customer = customers.firstWhere(
        (c) => c.id == _customer.id,
        orElse: () => _customer,
      );
      _ledgerFuture = ledger;
    });
  }

  Future<void> _openSettleCredit() async {
    if (_customer.currentBalance <= 0) {
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
        builder: (_) => NewSaleScreen(settlementCustomer: _customer),
      ),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final hasBalance = _customer.currentBalance > 0;
    final dateFmt = DateFormat('yyyy-MM-dd  HH:mm');

    return Scaffold(
      appBar: AppBar(title: Text(_customer.name)),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: hasBalance ? AppColors.warnSoft : AppColors.goodSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_customer.phone != null) ...[
                    Text(
                      _customer.phone!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    hasBalance
                        ? 'Owes Rs. ${_customer.currentBalance.toStringAsFixed(2)}'
                        : 'No outstanding balance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: hasBalance ? AppColors.warn : AppColors.good,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Credit limit: Rs. ${_customer.creditLimit.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (hasBalance) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: _openSettleCredit,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Settle Credit'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'History',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<CustomerLedgerEntry>>(
              future: _ledgerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('Error: ${snapshot.error}')),
                  );
                }
                final entries = snapshot.data ?? [];
                if (entries.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No transactions yet.',
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    ),
                  );
                }
                return Column(
                  children: entries
                      .map(
                        (e) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: e.isSale
                                        ? AppColors.warnSoft
                                        : AppColors.goodSoft,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    e.isSale
                                        ? Icons.receipt_long_outlined
                                        : Icons.payments_outlined,
                                    size: 17,
                                    color: e.isSale
                                        ? AppColors.warn
                                        : AppColors.good,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.isSale ? 'Credit Sale' : 'Payment',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          dateFmt.format(e.createdAt.toLocal()),
                                          if (e.referenceLabel != null)
                                            e.referenceLabel!,
                                        ].join('  ·  '),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${e.isSale ? '+' : '-'} Rs. ${e.amount.abs().toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: e.isSale
                                            ? AppColors.warn
                                            : AppColors.good,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Bal: Rs. ${e.balanceAfter.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.inkSoft,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
