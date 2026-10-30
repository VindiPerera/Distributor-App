import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/sale_detail.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../services/sale_service.dart';
import '../theme.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart' show orderStatusColors;

/// Shows the products on an order. Pending orders can be edited or
/// cancelled; completed/cancelled ones are read-only. Pops `true` when
/// something changed so the list behind it refreshes.
class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final SaleService _saleService;
  late Future<SaleDetail> _future;
  bool _changed = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _saleService = SaleService(context.read<AuthProvider>().api);
    _future = _saleService.get(widget.orderId);
  }

  void _reload() => setState(() => _future = _saleService.get(widget.orderId));

  Future<void> _edit(SaleDetail order) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NewOrderScreen(editing: order)),
    );
    if (saved == true) {
      _changed = true;
      _reload();
    }
  }

  Future<void> _cancel(SaleDetail order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: Text(
          'Order #${order.invoiceNumber} will be cancelled and its items returned to stock.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.critical),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _saleService.cancelOrder(order.id);
      _changed = true;
      _reload();
    } on ApiException catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not cancel the order.')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: FutureBuilder<SaleDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Could not load order.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    TextButton(onPressed: _reload, child: const Text('Retry')),
                  ],
                ),
              );
            }
            return _buildBody(snapshot.data!);
          },
        ),
      ),
    );
  }

  Widget _buildBody(SaleDetail order) {
    final badge =
        orderStatusColors[order.status] ??
        (bg: AppColors.lineSoft, fg: AppColors.inkSoft);
    final isPending = order.status == 'pending';
    final dateFmt = DateFormat('MMM d, y  h:mm a');

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Order #${order.invoiceNumber}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badge.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            order.status[0].toUpperCase() +
                                order.status.substring(1),
                            style: TextStyle(
                              fontSize: 12,
                              color: badge.fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateFmt.format(order.saleDate.toLocal()),
                      style: const TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                    const Divider(height: 24),
                    _InfoRow(
                      icon: Icons.person_outline_rounded,
                      text: order.customerName ?? 'Unknown customer',
                      bold: true,
                    ),
                    if (order.customerPhone != null &&
                        order.customerPhone!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        text: order.customerPhone!,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Card(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Products (${order.items.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    for (final item in order.items)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.accentSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${item.quantity}×',
                                style: const TextStyle(
                                  color: AppColors.accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${item.discountedPrice.toStringAsFixed(2)} each',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Rs. ${item.lineTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            'Rs. ${order.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.notes!,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isPending)
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
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _cancel(order),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.critical,
                        side: const BorderSide(color: AppColors.critical),
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel Order'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : () => _edit(order),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit Order'),
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

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.softShadow,
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool bold;

  const _InfoRow({required this.icon, required this.text, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: bold ? AppColors.ink : AppColors.inkSoft,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
