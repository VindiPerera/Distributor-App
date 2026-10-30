import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../models/receipt_data.dart';
import '../models/shop_settings.dart';
import 'api_client.dart';

const String _receiptWhatsapp = '072 665 0786';
const String _receiptEmail = 'info.damsascreations@gmail.com';

/// Printed on every receipt regardless of shop settings — this app is built
/// and distributed by JAAN Network, not something the admin can turn off.
const String _poweredBy = 'Powered by JAAN Network (PVT) Ltd';

const Map<String, String> _paymentLabels = {
  'cash': 'Cash',
  'credit': 'Credit',
  'credit_settlement': 'Credit Settlement',
};

class PrinterDevice {
  final String name;
  final String address;

  PrinterDevice({required this.name, required this.address});
}

class BluetoothPrinterService {
  /// True only if every piece of text on the receipt fits in the printer's
  /// built-in Latin-1 character set. Thermal printer firmware has no
  /// Sinhala (or other non-Latin) font, so [printReceipt]'s native ESC/POS
  /// text commands throw if any field falls outside Latin-1 - most often a
  /// product name typed in Sinhala, even when the shop's receipt language
  /// is set to English. Callers should check this (in addition to the
  /// language setting) before choosing between [printReceipt] and
  /// [printReceiptImage].
  static bool canPrintAsText(ReceiptData receipt, ShopSettings shop) {
    final fields = <String>[
      shop.name,
      shop.address,
      shop.phone,
      shop.companyPhone,
      shop.taxId,
      shop.footerNote,
      receipt.customerName ?? '',
      receipt.cashierName,
      for (final line in receipt.lines) line.name,
      for (final r in receipt.returns) r.name,
    ];
    return fields.every((s) => s.runes.every((r) => r <= 0xFF));
  }

  /// Android 12+ (API 31+) treats BLUETOOTH_CONNECT/SCAN as runtime
  /// permissions: declaring them in the manifest alone does nothing, they
  /// must be explicitly granted or every connect/write call silently fails
  /// even though the printer shows up as paired at the OS level.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<bool> isBluetoothEnabled() => PrintBluetoothThermal.bluetoothEnabled;

  Future<List<PrinterDevice>> listPairedDevices() async {
    final results = await PrintBluetoothThermal.pairedBluetooths;
    return results
        .map((d) => PrinterDevice(name: d.name, address: d.macAdress))
        .toList();
  }

  /// The native Android side of print_bluetooth_thermal keeps its
  /// BluetoothSocket output stream in a top-level variable that persists
  /// across connect() calls: if a previous session left it non-null (e.g.
  /// the app was killed mid-print, or a prior connect/write failed), every
  /// later connect() call is a no-op that returns false and never opens a
  /// fresh socket - because the plugin's "else" branch that's supposed to
  /// clear it (`outputStream == null`) is a no-op comparison, not an
  /// assignment. Forcing a disconnect() first guarantees that stale state
  /// is actually cleared before we ask for a new connection.
  Future<bool> connect(String address) async {
    await PrintBluetoothThermal.disconnect;
    return PrintBluetoothThermal.connect(macPrinterAddress: address);
  }

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<void> disconnect() => PrintBluetoothThermal.disconnect;

  /// Prints the receipt using the printer's built-in font via native
  /// ESC/POS text commands (English/Latin only - no font rendering, no
  /// image raster, no printer-dot-width pitfalls).
  Future<bool> printReceipt(ReceiptData receipt, ShopSettings shop) async {
    late final CapabilityProfile profile;
    late final Generator generator;
    try {
      profile = await CapabilityProfile.load();
      generator = Generator(
        shop.paperSize == 'mm80' ? PaperSize.mm80 : PaperSize.mm58,
        profile,
      );
    } catch (e, st) {
      throw Exception('[stage:generatorInit] $e\n$st');
    }

    final bytes = <int>[];
    try {
      bytes.addAll(generator.reset());
      bytes.addAll(await _buildLogo(generator));
      bytes.addAll(_buildHeader(generator, shop));
      bytes.addAll(_buildMeta(generator, receipt));
      bytes.addAll(_buildItemsTable(generator, receipt));
      bytes.addAll(_buildTotals(generator, receipt));
      bytes.addAll(_buildFooter(generator, shop));
      bytes.addAll(generator.feed(2));
      bytes.addAll(generator.cut());
    } catch (e, st) {
      throw Exception('[stage:build] $e\n$st');
    }

    return _write(bytes);
  }

  /// Captures [boundaryKey]'s widget as a bitmap and prints it as a single
  /// ESC/POS raster image. Used for Sinhala receipts, since thermal printer
  /// firmware has no Sinhala font and native ESC/POS text commands can only
  /// render the printer's built-in (Latin/CP437) character set.
  Future<bool> printReceiptImage(
    GlobalKey boundaryKey, {
    String paperSize = 'mm58',
  }) async {
    late final Uint8List pngBytes;
    try {
      // pixelRatio must stay 1.0: ReceiptWidget is already sized to the
      // printer's real dot width (384px for 58mm / 576px for 80mm paper at
      // 203dpi). Capturing at a higher ratio produces a wider bitmap than
      // the printhead, which imageRaster prints at full width - only the
      // left portion fits and the rest is clipped off the paper's edge.
      final boundary =
          boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final uiImage = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      pngBytes = byteData!.buffer.asUint8List();
    } catch (e, st) {
      throw Exception('[stage:capture] $e\n$st');
    }

    late final List<int> bytes;
    try {
      final decoded = img.decodePng(pngBytes)!;
      // esc_pos_utils_plus 2.0.4's Generator._toRasterFormat pads non-multiple
      // -of-8 widths by inserting into a List.filled (fixed-length) list,
      // which throws "Cannot add to a fixed-length list". Padding the width
      // to a multiple of 8 ourselves beforehand avoids that code path
      // entirely, since a captured widget's pixel width is essentially never
      // already a multiple of 8.
      final paddedWidth = (decoded.width + 7) & ~7;
      final image = paddedWidth == decoded.width
          ? decoded
          : img.copyExpandCanvas(
              decoded,
              newWidth: paddedWidth,
              newHeight: decoded.height,
              position: img.ExpandCanvasPosition.topLeft,
              backgroundColor: img.ColorRgb8(255, 255, 255),
            );

      final profile = await CapabilityProfile.load();
      final generator = Generator(
        paperSize == 'mm80' ? PaperSize.mm80 : PaperSize.mm58,
        profile,
      );

      bytes = <int>[
        ...generator.reset(),
        ...generator.imageRaster(image),
        ...generator.feed(2),
        ...generator.cut(),
      ];
    } catch (e, st) {
      throw Exception('[stage:build] $e\n$st');
    }

    return _write(bytes);
  }

  /// Must stay a plain `List<int>`: the plugin's Android side casts the
  /// platform channel argument directly to java.util.List, so passing a
  /// Uint8List (which crosses as a Java byte[]) throws a
  /// ClassCastException on the native side. That exception is swallowed by
  /// the method channel error handler and surfaces to Dart as a plain
  /// "false" return - looks identical to a real write failure.
  Future<bool> _write(List<int> bytes) async {
    try {
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
      if (!ok) {
        final stillConnected = await PrintBluetoothThermal.connectionStatus;
        throw Exception(
          '[stage:writeBytes] writeBytes returned false (connectionStatus=$stillConnected)',
        );
      }
      return ok;
    } catch (e, st) {
      if (e is Exception && e.toString().contains('[stage:writeBytes]'))
        rethrow;
      throw Exception('[stage:writeBytes] $e\n$st');
    }
  }

  /// Fetches and rasters the shop logo above the text header. Best-effort:
  /// any failure (network, decode) just skips the logo rather than failing
  /// the whole receipt print, since the logo isn't essential information.
  Future<List<int>> _buildLogo(Generator generator) async {
    try {
      Uint8List? imageBytes;
      try {
        final byteData = await rootBundle.load('assets/images/logo.png');
        imageBytes = byteData.buffer.asUint8List();
      } catch (_) {
        final response = await http
            .get(Uri.parse(ApiClient.logoUrl))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      }

      if (imageBytes == null) return const [];

      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return const [];

      final resized = img.copyResize(decoded, width: 200);

      final bytes = <int>[];
      bytes.addAll(generator.imageRaster(resized, align: PosAlign.center));
      bytes.addAll(generator.feed(1));
      return bytes;
    } catch (_) {
      return const [];
    }
  }

  List<int> _buildHeader(Generator generator, ShopSettings shop) {
    final bytes = <int>[];
    bytes.addAll(
      generator.text(
        shop.name,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );
    if (shop.address.isNotEmpty) {
      bytes.addAll(
        generator.text(
          shop.address,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (shop.phone.isNotEmpty) {
      bytes.addAll(
        generator.text(
          shop.phone,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    if (shop.companyPhone.isNotEmpty) {
      bytes.addAll(
        generator.text(
          shop.companyPhone,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    bytes.addAll(
      generator.text(
        'WhatsApp: $_receiptWhatsapp',
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    bytes.addAll(
      generator.text(
        _receiptEmail,
        styles: const PosStyles(align: PosAlign.center),
      ),
    );
    if (shop.taxId.isNotEmpty) {
      bytes.addAll(
        generator.text(
          shop.taxId,
          styles: const PosStyles(align: PosAlign.center),
        ),
      );
    }
    bytes.addAll(generator.hr(linesAfter: 1));
    return bytes;
  }

  List<int> _buildMeta(Generator generator, ReceiptData receipt) {
    final bytes = <int>[];
    final dateStr =
        '${receipt.date.year}-${receipt.date.month.toString().padLeft(2, '0')}-${receipt.date.day.toString().padLeft(2, '0')}  '
        '${receipt.date.hour.toString().padLeft(2, '0')}:${receipt.date.minute.toString().padLeft(2, '0')}';

    bytes.addAll(_kv(generator, 'Invoice', receipt.invoiceNumber));
    bytes.addAll(_kv(generator, 'Date', dateStr));
    bytes.addAll(_kv(generator, 'Payment', _paymentLabel(receipt.paymentType)));
    if (receipt.customerName != null) {
      bytes.addAll(_kv(generator, 'Customer', receipt.customerName!));
    }
    if (receipt.customerPhone != null) {
      bytes.addAll(_kv(generator, 'Phone', receipt.customerPhone!));
    }
    bytes.addAll(_kv(generator, 'Cashier', receipt.cashierName));
    bytes.addAll(generator.hr(linesAfter: 1));
    return bytes;
  }

  List<int> _buildItemsTable(Generator generator, ReceiptData receipt) {
    final bytes = <int>[];
    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'Product',
          width: 5,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: 'Our Price',
          width: 3,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
        PosColumn(
          text: 'Qty',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
        PosColumn(
          text: 'Total',
          width: 2,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]),
    );
    bytes.addAll(generator.hr(linesAfter: 1));

    for (final line in receipt.lines) {
      // generator.text() wraps automatically at the printer's character
      // width, so a long product name spans extra lines instead of
      // truncating.
      bytes.addAll(
        generator.text(line.name, styles: const PosStyles(bold: true)),
      );
      bytes.addAll(
        generator.text(
          'Rs. ${line.unitPrice.toStringAsFixed(2)} each',
          styles: const PosStyles(fontType: PosFontType.fontB),
        ),
      );
      bytes.addAll(
        generator.row([
          PosColumn(text: '', width: 5),
          PosColumn(
            text: 'Rs. ${line.discountedPrice.toStringAsFixed(2)}',
            width: 3,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: 'x${line.quantity}',
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
          PosColumn(
            text: 'Rs. ${line.lineTotal.toStringAsFixed(2)}',
            width: 2,
            styles: const PosStyles(align: PosAlign.right),
          ),
        ]),
      );
    }
    bytes.addAll(generator.hr(linesAfter: 1));
    return bytes;
  }

  List<int> _buildTotals(Generator generator, ReceiptData receipt) {
    final bytes = <int>[];

    if (receipt.returns.isNotEmpty) {
      bytes.addAll(
        generator.text('Returns:', styles: const PosStyles(bold: true)),
      );
      for (final r in receipt.returns) {
        bytes.addAll(
          _kv(
            generator,
            '${r.name} x${r.quantity}',
            '- Rs. ${r.amount.toStringAsFixed(2)}',
          ),
        );
      }
      bytes.addAll(
        _kv(
          generator,
          'Subtotal',
          'Rs. ${receipt.subtotal.toStringAsFixed(2)}',
        ),
      );
      bytes.addAll(
        _kv(
          generator,
          'Returns',
          '- Rs. ${receipt.returnAmount.toStringAsFixed(2)}',
        ),
      );
    }

    bytes.addAll(
      generator.row([
        PosColumn(
          text: 'TOTAL',
          width: 6,
          styles: const PosStyles(bold: true, height: PosTextSize.size2),
        ),
        PosColumn(
          text: 'Rs. ${receipt.total.toStringAsFixed(2)}',
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
            bold: true,
            height: PosTextSize.size2,
          ),
        ),
      ]),
    );

    return bytes;
  }

  List<int> _buildFooter(Generator generator, ShopSettings shop) {
    final bytes = <int>[];
    if (shop.footerNote.isNotEmpty) {
      // Printed larger (size2) so the thank-you message stands out at the
      // bottom of the receipt.
      bytes.addAll(
        generator.text(
          shop.footerNote,
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
          linesAfter: 1,
        ),
      );
    }
    bytes.addAll(
      generator.text(
        _poweredBy,
        styles: const PosStyles(align: PosAlign.center),
        linesAfter: 1,
      ),
    );
    return bytes;
  }

  List<int> _kv(Generator generator, String label, String value) {
    return generator.row([
      PosColumn(text: label, width: 5),
      PosColumn(
        text: value,
        width: 7,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
  }

  String _paymentLabel(String type) {
    return _paymentLabels[type] ??
        (type.isEmpty ? type : type[0].toUpperCase() + type.substring(1));
  }
}
