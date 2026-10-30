import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sale.dart';
import '../providers/auth_provider.dart';
import '../services/sale_service.dart';
import '../theme.dart';
import 'new_order_screen.dart';
import 'order_detail_screen.dart';

const orderStatusColors = {
  'pending': (bg: AppColors.warnSoft, fg: AppColors.warn),
  'cancelled': (bg: AppColors.criticalSoft, fg: AppColors.critical),
  'completed': (bg: AppColors.goodSoft, fg: AppColors.good),
};

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final SaleService _saleService;
  late Future<List<Sale>> _future;
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _statusFilter = 'all';

  static const _filters = ['all', 'pending', 'completed', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _saleService = SaleService(context.read<AuthProvider>().api);
    _future = _saleService.list();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() => _future = _saleService.list(search: _searchController.text));
  }

  /// Waits for a pause in typing before hitting the API.
  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
    setState(() {});
  }

  Future<void> _open(Sale sale) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: sale.id)),
    );
    if (changed == true) _reload();
  }

  Future<void> _newOrder() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewOrderScreen()),
    );
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newOrder,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Order'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search by customer name or order ID',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _reload();
                        },
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                return ChoiceChip(
                  label: Text(f[0].toUpperCase() + f.substring(1)),
                  selected: _statusFilter == f,
                  showCheckmark: false,
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.line),
                  labelStyle: TextStyle(
                    color: _statusFilter == f
                        ? Colors.white
                        : AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() => _statusFilter = f),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: FutureBuilder<List<Sale>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _Message(
                    icon: Icons.cloud_off_rounded,
                    text: 'Could not load orders.\n${snapshot.error}',
                    action: TextButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  );
                }
                final all = snapshot.data ?? [];
                final orders = _statusFilter == 'all'
                    ? all
                    : all.where((s) => s.status == _statusFilter).toList();
                if (orders.isEmpty) {
                  return _Message(
                    icon: Icons.assignment_outlined,
                    text:
                        _searchController.text.isNotEmpty ||
                            _statusFilter != 'all'
                        ? 'No orders match your search.'
                        : 'No orders yet.\nTap "New Order" to take one.',
                  );
                }
                return RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _OrderCard(
                      sale: orders[i],
                      onTap: () => _open(orders[i]),
                    ),
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

class _OrderCard extends StatelessWidget {
  final Sale sale;
  final VoidCallback onTap;

  const _OrderCard({required this.sale, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badge =
        orderStatusColors[sale.status] ??
        (bg: AppColors.lineSoft, fg: AppColors.inkSoft);
    final dateFmt = DateFormat('MMM d, y  h:mm a');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sale.customerName ?? 'Unknown customer',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Order #${sale.invoiceNumber}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateFmt.format(sale.saleDate.toLocal()),
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
                      'Rs. ${sale.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badge.bg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sale.status[0].toUpperCase() + sale.status.substring(1),
                        style: TextStyle(
                          fontSize: 11,
                          color: badge.fg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: AppColors.inkSoft.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, height: 1.4),
            ),
            if (action != null) action!,
          ],
        ),
      ),
    );
  }
}
