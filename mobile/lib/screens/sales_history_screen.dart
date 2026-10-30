import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/receipt_data.dart';
import '../models/sale.dart';
import '../providers/auth_provider.dart';
import '../services/sale_service.dart';
import '../theme.dart';
import 'receipt_preview_screen.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  late final SaleService _saleService;
  late Future<List<Sale>> _future;
  final Set<int> _loadingIds = {};

  static const _paymentBadgeColors = {
    'cash': (bg: AppColors.goodSoft, fg: AppColors.good),
    'card': (bg: AppColors.goodSoft, fg: AppColors.good),
    'bank_transfer': (bg: AppColors.goodSoft, fg: AppColors.good),
    'credit': (bg: AppColors.warnSoft, fg: AppColors.warn),
    'split': (bg: AppColors.accentSoft, fg: AppColors.accent),
  };

  static const _statusBadgeColors = {
    'pending': (bg: AppColors.warnSoft, fg: AppColors.warn),
    'cancelled': (bg: AppColors.criticalSoft, fg: AppColors.critical),
    'completed': (bg: AppColors.goodSoft, fg: AppColors.good),
  };

  @override
  void initState() {
    super.initState();
    _saleService = SaleService(context.read<AuthProvider>().api);
    _future = _saleService.list();
  }

  void _reload() {
    setState(() => _future = _saleService.list());
  }

  String _paymentLabel(String type) {
    switch (type) {
      case 'bank_transfer':
        return 'Bank Transfer';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }

  Future<void> _openBill(Sale sale) async {
    setState(() => _loadingIds.add(sale.id));
    try {
      final detail = await _saleService.get(sale.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ReceiptPreviewScreen(receipt: ReceiptData.fromSaleDetail(detail)),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load bill: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove(sale.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('MMM d, y  h:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('Sales History')),
      body: FutureBuilder<List<Sale>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final sales = snapshot.data ?? [];
          if (sales.isEmpty) {
            return const Center(
              child: Text(
                'No sales yet.',
                style: TextStyle(color: AppColors.inkSoft),
              ),
            );
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async => _reload(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sales.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = sales[i];
                final badge =
                    _paymentBadgeColors[s.paymentType] ??
                    (bg: AppColors.lineSoft, fg: AppColors.inkSoft);
                final statusBadge =
                    _statusBadgeColors[s.status] ??
                    (bg: AppColors.lineSoft, fg: AppColors.inkSoft);
                final isLoading = _loadingIds.contains(s.id);

                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: isLoading ? null : () => _openBill(s),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.invoiceNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: AppColors.ink,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: badge.bg,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        _paymentLabel(s.paymentType),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: badge.fg,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusBadge.bg,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    s.status[0].toUpperCase() +
                                        s.status.substring(1),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: statusBadge.fg,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.customerName ?? 'Walk-in Customer',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateFmt.format(s.saleDate.toLocal()),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs. ${s.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (isLoading)
                                const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.receipt_long_outlined,
                                  size: 18,
                                  color: AppColors.inkSoft,
                                ),
                            ],
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
    );
  }
}
