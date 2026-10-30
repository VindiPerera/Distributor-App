import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/receipt_data.dart';
import '../models/shop_settings.dart';
import '../providers/auth_provider.dart';
import '../services/bluetooth_printer_service.dart';
import '../services/shop_settings_service.dart';
import '../theme.dart';
import '../widgets/receipt_widget.dart';

class ReceiptPreviewScreen extends StatefulWidget {
  final ReceiptData receipt;

  const ReceiptPreviewScreen({super.key, required this.receipt});

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  final _boundaryKey = GlobalKey();
  final _printerService = BluetoothPrinterService();
  late final ShopSettingsService _settingsService;

  ShopSettings? _shop;
  bool _isPrinting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _settingsService = ShopSettingsService(context.read<AuthProvider>().api);
    _settingsService.load().then(
      (s) => setState(() => _shop = s),
      onError: (_) => setState(() => _shop = ShopSettings.fallback),
    );
  }

  Future<void> _print() async {
    setState(() {
      _isPrinting = true;
      _error = null;
    });

    try {
      final permitted = await _printerService.requestPermissions();
      if (!permitted) {
        setState(
          () => _error =
              'Bluetooth permission is required to print. Grant it in app settings.',
        );
        return;
      }

      final enabled = await _printerService.isBluetoothEnabled();
      if (!enabled) {
        setState(() => _error = 'Turn on Bluetooth to print.');
        return;
      }

      final devices = await _printerService.listPairedDevices();
      if (devices.isEmpty) {
        setState(
          () => _error =
              'No paired Bluetooth printer found. Pair your printer in phone settings first.',
        );
        return;
      }

      final selected = devices.length == 1
          ? devices.first
          : await _pickDevice(devices);
      if (selected == null) {
        setState(() => _error = 'No printer selected.');
        return;
      }

      final connected = await _printerService.connect(selected.address);
      if (!connected) {
        setState(() => _error = 'Could not connect to ${selected.name}.');
        return;
      }

      // Thermal printer firmware has no Sinhala font, so native ESC/POS text
      // commands can't render it - fall back to printing a bitmap of the
      // same widget shown in the preview above, which already renders
      // Sinhala correctly via NotoSansSinhala. Triggered either by the
      // shop's configured receipt language, or by the receipt's actual
      // content (e.g. a product name typed in Sinhala even though the shop
      // otherwise prints in English) - checking only the language setting
      // let such receipts fall through to the native path and crash.
      final needsImage =
          _shop!.receiptLanguage == 'si' ||
          !BluetoothPrinterService.canPrintAsText(widget.receipt, _shop!);
      final printed = needsImage
          ? await _printerService.printReceiptImage(
              _boundaryKey,
              paperSize: _shop!.paperSize,
            )
          : await _printerService.printReceipt(widget.receipt, _shop!);
      if (mounted) {
        if (printed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receipt sent to printer.')),
          );
        } else {
          setState(
            () => _error = 'Printing failed. Check the printer and try again.',
          );
        }
      }
    } catch (e, st) {
      debugPrint('Printing failed: $e\n$st');
      setState(() => _error = 'Printing failed: $e');
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  Future<PrinterDevice?> _pickDevice(List<PrinterDevice> devices) {
    return showModalBottomSheet<PrinterDevice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Printer',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            for (final d in devices)
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: Text(d.name.isEmpty ? d.address : d.name),
                subtitle: Text(d.address),
                onTap: () => Navigator.pop(context, d),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _shop == null
              ? 'Receipt'
              : 'Receipt (paperSize: ${_shop!.paperSize})',
        ),
      ),
      body: _shop == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.line),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 8),
                          ],
                        ),
                        child: RepaintBoundary(
                          key: _boundaryKey,
                          child: ReceiptWidget(
                            shop: _shop!,
                            receipt: widget.receipt,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
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
                            _error!,
                            style: const TextStyle(
                              color: AppColors.critical,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isPrinting ? null : _print,
                          icon: _isPrinting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.bluetooth_rounded, size: 20),
                          label: Text(
                            _isPrinting ? 'Printing…' : 'Print via Bluetooth',
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
