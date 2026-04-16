import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/models.dart';
import './coffee_collection_service.dart';
import './settings_service.dart';
import 'inventory_service.dart';
import 'member_service.dart';
import 'permission_service.dart';

// ─── Thermal Receipt Font Scale ──────────────────────────────────────────────
// Standard 80mm thermal printer fonts (ESC/POS equivalents):
//   Body text      → 8 pt
//   Secondary      → 7.5 pt  (labels, sub-info)
//   Section header → 9 pt    (bold)
//   Key totals     → 10 pt   (bold)
//   Org name       → 11 pt   (bold, largest element)
// Line spacing is kept tight to match thermal roll expectations.
// ─────────────────────────────────────────────────────────────────────────────

// Define print method enum
enum PrintMethod { bluetooth, direct }

class PrintService extends GetxService {
  static PrintService get to => Get.find();

  PermissionService? _permissionService;

  final Rx<PrintMethod> currentPrintMethod = PrintMethod.bluetooth.obs;
  final RxList<dynamic> availablePrinters = <dynamic>[].obs;
  final Rx<dynamic> selectedPrinter = Rx<dynamic>(null);

  RxString printMethod = 'bluetooth'.obs;
  Rx<dynamic> connectedPrinter = Rx<dynamic>(null);

  Future<PrintService> init() async {
    try {
      _permissionService = Get.find<PermissionService>();
    } catch (e) {
      print('Warning: PermissionService not found, continuing without it: $e');
    }
    await discoverPrinters();
    await loadSavedDefaultPrinter();
    if (selectedPrinter.value == null) {
      await ensureSystemDefaultPrinter();
    }
    return this;
  }

  bool get isPrintingAvailable {
    try {
      return availablePrinters.isNotEmpty || selectedPrinter.value != null;
    } catch (e) {
      return false;
    }
  }

  void _showPrintingNotAvailableMessage() {
    Get.snackbar(
      'Printing Not Available',
      'Printing functionality is not supported on this device or platform',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }

  Future<void> discoverPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      availablePrinters.value = printers;
      dynamic defaultPrinter = _findDefaultPrinter(printers);
      if (defaultPrinter != null) {
        selectedPrinter.value = defaultPrinter;
      } else if (printers.isNotEmpty && selectedPrinter.value == null) {
        selectedPrinter.value = printers.first;
      }
    } on MissingPluginException catch (e) {
      print('Printing plugin not available on this platform: $e');
      availablePrinters.value = [];
    } catch (e) {
      print('Error discovering printers: $e');
      availablePrinters.value = [];
    }
  }

  dynamic _findDefaultPrinter(List<dynamic> printers) {
    try {
      for (var printer in printers) {
        try {
          if (printer?.isDefault == true) return printer;
        } catch (_) {}
        try {
          if (printer?.name != null &&
              printer.name.toLowerCase().contains('default')) {
            return printer;
          }
        } catch (_) {}
      }
      if (printers.isNotEmpty) return printers.first;
    } catch (e) {
      print('Error finding default printer: $e');
    }
    return null;
  }

  Future<dynamic> getSystemDefaultPrinter() async {
    try {
      final printers = await Printing.listPrinters();
      return _findDefaultPrinter(printers);
    } on MissingPluginException catch (e) {
      print('Printing plugin not available: $e');
      return null;
    } catch (e) {
      print('Error getting system default printer: $e');
      return null;
    }
  }

  Future<void> ensureSystemDefaultPrinter() async {
    try {
      final defaultPrinter = await getSystemDefaultPrinter();
      if (defaultPrinter != null) {
        selectedPrinter.value = defaultPrinter;
        await _saveDefaultPrinterPreference(defaultPrinter);
      }
    } catch (e) {
      print('Error ensuring system default printer: $e');
    }
  }

  Future<void> _saveDefaultPrinterPreference(dynamic printer) async {
    try {
      if (printer?.name != null) {
        final settingsService = Get.find<SettingsService>();
        await settingsService.saveSetting('default_printer_name', printer.name);
      }
    } catch (e) {
      print('Error saving default printer preference: $e');
    }
  }

  Future<void> loadSavedDefaultPrinter() async {
    try {
      final settingsService = Get.find<SettingsService>();
      final savedPrinterName = await settingsService.getSetting(
        'default_printer_name',
      );
      if (savedPrinterName != null && availablePrinters.isNotEmpty) {
        for (var printer in availablePrinters) {
          try {
            if (printer?.name == savedPrinterName) {
              selectedPrinter.value = printer;
              return;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      print('Error loading saved default printer: $e');
    }
  }

  void setPrintMethod(String method) {
    printMethod.value = method;
    currentPrintMethod.value =
        method == 'bluetooth' ? PrintMethod.bluetooth : PrintMethod.direct;
  }

  void setSelectedPrinter(dynamic printer) {
    selectedPrinter.value = printer;
    _saveDefaultPrinterPreference(printer);
  }

  Future<void> refreshAndSelectDefaultPrinter() async {
    try {
      await discoverPrinters();
      await ensureSystemDefaultPrinter();
    } catch (e) {
      print('Error refreshing printers: $e');
    }
  }

  Future<bool> _checkPrintingPermissions() async {
    if (!Platform.isAndroid) return true;

    if (currentPrintMethod.value == PrintMethod.bluetooth) {
      bool hasBluetoothPermission = false;
      if (_permissionService != null) {
        hasBluetoothPermission =
            await _permissionService!.checkBluetoothPermission();
      }
      if (!hasBluetoothPermission) {
        bool hasLocationPermission = false;
        if (_permissionService != null) {
          hasLocationPermission =
              await _permissionService!.checkLocationPermission();
        }
        if (!hasLocationPermission) {
          final locationGranted = await _ensureLocationPermissionForFeature(
            'Bluetooth printing',
          );
          if (!locationGranted) {
            Get.snackbar(
              'Location Permission Required',
              'Location access is needed for Bluetooth printing',
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: Colors.orange,
              colorText: Colors.white,
              duration: const Duration(seconds: 4),
            );
          }
        }
        if (_permissionService != null) {
          hasBluetoothPermission =
              await _permissionService!.requestBluetoothPermission();
        }
        if (!hasBluetoothPermission) {
          Get.snackbar(
            'Permission Required',
            'Bluetooth permission is needed for printing receipts',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return false;
        }
      }
    }

    bool hasStoragePermission = false;
    if (_permissionService != null) {
      hasStoragePermission = await _permissionService!.checkStoragePermission();
    }
    if (!hasStoragePermission) {
      if (_permissionService != null) {
        hasStoragePermission =
            await _permissionService!.requestStoragePermission();
      }
      if (!hasStoragePermission) {
        Get.snackbar(
          'Storage Permission Denied',
          'Unable to print receipts without storage access',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> printReceipt(Map<String, dynamic> receiptData) async {
    if (!await _checkPrintingPermissions()) return;
    if (currentPrintMethod.value == PrintMethod.direct) {
      await ensureSystemDefaultPrinter();
    }

    final isInventorySale = receiptData['type'] == 'sale';
    int copiesToPrint = 1;
    if (isInventorySale) {
      try {
        final settingsService = Get.find<SettingsService>();
        copiesToPrint = settingsService.systemSettings.value.receiptDuplicates;
      } catch (e) {
        copiesToPrint = 1;
      }
    }

    if (currentPrintMethod.value == PrintMethod.bluetooth) {
      await _printViaBluetoothPrinter(receiptData, copiesToPrint);
    } else {
      await _printViaDirectPrinter(receiptData, copiesToPrint);
    }
  }

  Future<void> _printViaBluetoothPrinter(
    Map<String, dynamic> receiptData,
    int copies,
  ) async {
    try {
      final pdf = await _generateReceiptPdf(receiptData, copies: copies);
      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf,
          name: 'Receipt',
        );
      } on MissingPluginException catch (e) {
        print('Printing plugin not available: $e');
        _showPrintingNotAvailableMessage();
      }
    } catch (e) {
      print('Error printing via Bluetooth: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print receipt: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _printViaDirectPrinter(
    Map<String, dynamic> receiptData,
    int copies,
  ) async {
    try {
      if (selectedPrinter.value == null) {
        throw Exception('No printer selected for direct printing');
      }
      final pdf = await _generateReceiptPdf(receiptData, copies: copies);
      try {
        await Printing.directPrintPdf(
          printer: selectedPrinter.value,
          onLayout: (_) => pdf,
        );
      } on MissingPluginException catch (e) {
        print('Printing plugin not available: $e');
        _showPrintingNotAvailableMessage();
        return;
      }
      Get.snackbar(
        'Success',
        'Receipt printed successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error printing via direct printer: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print receipt: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // ─── PDF Generation ─────────────────────────────────────────────────────────
  // Font size constants (points) aligned to 80mm thermal ESC/POS conventions.
  static const double _fsOrgName = 11.0;   // Society / org name — largest
  static const double _fsSubHeader = 9.0;  // Factory, address
  static const double _fsSection = 8.5;    // Section headings (ITEMS, WEIGHT…)
  static const double _fsBody = 8.0;       // Standard body rows
  static const double _fsSmall = 7.5;      // Labels, secondary info
  static const double _fsTotalKey = 9.0;   // Grand-total label
  static const double _fsTotalVal = 9.0;   // Grand-total value
  static const double _fsFooter = 7.0;     // Footer / slogan

  Future<Uint8List> _generateReceiptPdf(
    Map<String, dynamic> receiptData, {
    int copies = 1,
  }) async {
    final pdf = pw.Document();

    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);

    pw.MemoryImage? logoImage;
    if (receiptData['logoPath'] != null &&
        receiptData['logoPath'].toString().isNotEmpty) {
      try {
        final File logoFile = File(receiptData['logoPath'].toString());
        if (await logoFile.exists()) {
          final logoBytes = await logoFile.readAsBytes();
          if (logoBytes.isNotEmpty) logoImage = pw.MemoryImage(logoBytes);
        }
      } catch (e) {
        print('Error loading logo: $e');
      }
    }

    for (int copyNumber = 0; copyNumber < copies; copyNumber++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80.copyWith(
            marginLeft: 6,
            marginRight: 6,
            marginTop: 4,
            marginBottom: 6,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── LOGO ──────────────────────────────────────────────────
                if (logoImage != null) ...[
                  pw.Center(
                    child: pw.SizedBox(
                      height: 48,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ),
                  pw.SizedBox(height: 3),
                ],

                // ── ORG HEADER ────────────────────────────────────────────
                pw.Center(
                  child: pw.Text(
                    receiptData['societyName'] ?? 'Farm Fresh',
                    style: pw.TextStyle(
                      fontSize: _fsOrgName,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                if (receiptData['factory'] != null) ...[
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.Text(
                      receiptData['factory'],
                      style: pw.TextStyle(
                        fontSize: _fsSubHeader,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
                if (receiptData['societyAddress'] != null) ...[
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.Text(
                      receiptData['societyAddress'],
                      style: const pw.TextStyle(fontSize: _fsSmall),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
                if (receiptData['phoneNumber'] != null) ...[
                  pw.SizedBox(height: 1),
                  pw.Center(
                    child: pw.Text(
                      receiptData['phoneNumber'],
                      style: const pw.TextStyle(fontSize: _fsSmall),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    'Printed: $formattedDate  $formattedTime',
                    style: const pw.TextStyle(fontSize: _fsSmall),
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Divider(thickness: 0.5),
                pw.SizedBox(height: 2),

                // ── RECEIPT META ──────────────────────────────────────────
                _labelValueRow(
                  'Receipt #',
                  receiptData['receiptNumber'] ?? 'N/A',
                  bold: true,
                ),
                _labelValueRow('Member', receiptData['memberName'] ?? 'N/A', bold: true),
                _labelValueRow('Member #', receiptData['memberNumber'] ?? 'N/A'),
                _labelValueRow(
                  receiptData['type'] == 'coffee_collection'
                      ? 'Collection Date'
                      : 'Date',
                  receiptData['date'] ?? 'N/A',
                ),
                _labelValueRow('Served By', receiptData['servedBy'] ?? 'N/A', bold: true),
                pw.SizedBox(height: 3),

                // ── COFFEE COLLECTION DETAILS ─────────────────────────────
                if (receiptData['type'] == 'coffee_collection') ...[
                  _sectionHeader('COFFEE COLLECTION'),
                  _labelValueRow(
                    'Coffee Type',
                    receiptData['productType'] ?? 'N/A',
                    bold: true,
                  ),
                  _labelValueRow('Season', receiptData['seasonName'] ?? 'N/A'),
                  _labelValueRow('No. of Bags', receiptData['numberOfBags'] ?? 'N/A'),
                  pw.SizedBox(height: 3),
                ],

                // ── SALE ITEMS ────────────────────────────────────────────
                if (receiptData['type'] == 'sale') ...[
                  _sectionHeader('ITEMS'),
                  pw.SizedBox(height: 2),
                  // Column header row
                  pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          'Item',
                          style: pw.TextStyle(
                            fontSize: _fsSmall,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(
                        width: 28,
                        child: pw.Text(
                          'Qty',
                          style: pw.TextStyle(
                            fontSize: _fsSmall,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.SizedBox(
                        width: 36,
                        child: pw.Text(
                          'Price',
                          style: pw.TextStyle(
                            fontSize: _fsSmall,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                      pw.SizedBox(
                        width: 40,
                        child: pw.Text(
                          'Total',
                          style: pw.TextStyle(
                            fontSize: _fsSmall,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                  pw.Divider(thickness: 0.3),
                  // Item rows
                  ...((receiptData['items'] as List).map<pw.Widget>((item) {
                    return pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1),
                      child: pw.Row(
                        children: [
                          pw.Expanded(
                            flex: 4,
                            child: pw.Text(
                              item['productName'],
                              style: const pw.TextStyle(fontSize: _fsBody),
                            ),
                          ),
                          pw.SizedBox(
                            width: 28,
                            child: pw.Text(
                              item['quantity'],
                              style: const pw.TextStyle(fontSize: _fsBody),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.SizedBox(
                            width: 36,
                            child: pw.Text(
                              item['unitPrice'],
                              style: const pw.TextStyle(fontSize: _fsBody),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                          pw.SizedBox(
                            width: 40,
                            child: pw.Text(
                              item['totalPrice'],
                              style: const pw.TextStyle(fontSize: _fsBody),
                              textAlign: pw.TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  })),
                  pw.SizedBox(height: 2),
                  pw.Divider(thickness: 0.5),
                  // Totals
                  _labelValueRow(
                    'Subtotal',
                    receiptData['totalAmount'] ?? '0.00',
                    bold: true,
                    fontSize: _fsTotalKey,
                  ),
                  _labelValueRow('Paid', receiptData['paidAmount'] ?? '0.00'),
                  if (receiptData['saleType'] == 'CREDIT' &&
                      (double.tryParse(
                                receiptData['balanceAmount'] ?? '0',
                              ) ??
                              0) >
                          0) ...[
                    _labelValueRow(
                      'This Sale Balance',
                      receiptData['balanceAmount'] ?? '0.00',
                    ),
                    _labelValueRow(
                      'Total Balance',
                      'KSh ${receiptData['totalBalance'] ?? '0.00'}',
                      bold: true,
                      fontSize: _fsTotalKey,
                    ),
                  ],
                  _labelValueRow('Sale Mode', receiptData['saleType'] ?? 'N/A'),
                ] else ...[
                  // ── WEIGHT DETAILS ──────────────────────────────────────
                  _sectionHeader('WEIGHT DETAILS'),
                  if (receiptData['grossWeight'] != null &&
                      receiptData['totalTareWeight'] != null) ...[
                    _labelValueRow(
                      'Gross Weight',
                      '${receiptData['grossWeight']} kg',
                    ),
                    if (receiptData['tareWeightPerBag'] != null)
                      _labelValueRow(
                        'Tare / Bag',
                        '${receiptData['tareWeightPerBag']} kg',
                      ),
                    _labelValueRow(
                      'Total Tare',
                      '${receiptData['totalTareWeight']} kg',
                    ),
                    _labelValueRow(
                      'Net Weight',
                      '${receiptData['netWeight']} kg',
                      bold: true,
                      fontSize: _fsTotalKey,
                    ),
                  ] else ...[
                    _labelValueRow(
                      'Weight',
                      '${receiptData['weight'] ?? 'N/A'} kg',
                      bold: true,
                      fontSize: _fsTotalKey,
                    ),
                  ],
                ],

                // ── SEASON / CUMULATIVE TOTAL ─────────────────────────────
                if (receiptData['type'] == 'coffee_collection' &&
                    receiptData['allTimeCumulativeWeight'] != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Divider(thickness: 0.5),
                  _labelValueRow(
                    'Season Total',
                    '${receiptData['allTimeCumulativeWeight']} kg',
                    bold: true,
                    fontSize: _fsTotalKey,
                  ),
                ] else if (receiptData['cumulativeWeight'] != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Divider(thickness: 0.5),
                  _labelValueRow(
                    'Month-to-Date Total',
                    '${receiptData['cumulativeWeight']} kg',
                    bold: true,
                    fontSize: _fsTotalKey,
                  ),
                ],

                pw.SizedBox(height: 3),
                pw.Divider(thickness: 0.5),

                // ── SIGNATURE SECTION (non-collection) ───────────────────
                if (receiptData['type'] != 'coffee_collection') ...[
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'RECEIVED BY',
                    style: pw.TextStyle(
                      fontSize: _fsSmall,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'ID No: _______________________',
                    style: const pw.TextStyle(fontSize: _fsSmall),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Sign:  _______________________',
                    style: const pw.TextStyle(fontSize: _fsSmall),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.3),
                ],

                // ── FOOTER ────────────────────────────────────────────────
                pw.SizedBox(height: 2),
                pw.Center(
                  child: pw.Text(
                    receiptData['slogan'] ?? 'Thank you!',
                    style: const pw.TextStyle(fontSize: _fsFooter),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
                pw.SizedBox(height: 1),
                pw.Center(
                  child: pw.Text(
                    'A product of Inuka Technologies',
                    style: const pw.TextStyle(fontSize: _fsFooter),
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Renders a label-on-left / value-on-right row used throughout the receipt.
  pw.Widget _labelValueRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = _fsBody,
  }) {
    final style = bold
        ? pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold)
        : pw.TextStyle(fontSize: fontSize);
    final labelStyle = pw.TextStyle(fontSize: _fsSmall);

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 0.8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('$label:', style: labelStyle),
          pw.Text(value, style: style),
        ],
      ),
    );
  }

  /// Renders a bold section-header line with a thin underline.
  pw.Widget _sectionHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 2),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: _fsSection,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Divider(thickness: 0.3),
      ],
    );
  }

  // ─── Public API ─────────────────────────────────────────────────────────────

  Future<void> printReceiptWithDialog(Map<String, dynamic> receiptData) async {
    if (!await _checkPrintingPermissions()) return;

    try {
      final isInventorySale = receiptData['type'] == 'sale';
      int copiesToPrint = 1;
      if (isInventorySale) {
        try {
          final settingsService = Get.find<SettingsService>();
          copiesToPrint =
              settingsService.systemSettings.value.receiptDuplicates;
        } catch (e) {
          copiesToPrint = 1;
        }
      }

      final pdf = await _generateReceiptPdf(receiptData, copies: copiesToPrint);
      try {
        await Printing.layoutPdf(
          onLayout: (_) => pdf,
          name: 'Receipt ${receiptData['receiptNumber'] ?? ''}',
          format: PdfPageFormat.roll80.copyWith(
            marginLeft: 6,
            marginRight: 6,
            marginTop: 4,
            marginBottom: 6,
          ),
        );
      } on MissingPluginException catch (e) {
        print('Printing plugin not available: $e');
        _showPrintingNotAvailableMessage();
      }
    } catch (e) {
      print('Error printing with dialog: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print receipt: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<String?> saveReceiptToPdf(Map<String, dynamic> receiptData) async {
    try {
      bool hasPermission = false;
      if (_permissionService != null) {
        hasPermission = await _permissionService!.checkStoragePermission();
      }
      if (!hasPermission) {
        if (_permissionService != null) {
          hasPermission = await _permissionService!.requestStoragePermission();
        }
        if (!hasPermission) {
          Get.snackbar(
            'Permission Denied',
            'Storage permission is required to save receipts',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
          );
          return null;
        }
      }

      Directory? directory;
      try {
        directory = await getExternalStorageDirectory();
      } catch (e) {
        directory = await getApplicationDocumentsDirectory();
      }

      Directory receiptsDir = Directory('${directory?.path ?? ''}/receipts');
      if (!await receiptsDir.exists()) {
        await receiptsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final memberNumber = receiptData['memberNumber'] ?? 'unknown';
      final filePath =
          '${receiptsDir.path}/receipt_${memberNumber}_$timestamp.pdf';

      final pdf = await _generateReceiptPdf(receiptData);
      await File(filePath).writeAsBytes(pdf);
      return filePath;
    } catch (e) {
      print('Error saving PDF: $e');
      Get.snackbar(
        'Error',
        'Failed to save receipt: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return null;
    }
  }

  double calculateCoffeeMonthlyTotal(
    List<CoffeeCollection> collections,
    String memberNumber,
  ) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    return collections
        .where(
          (c) =>
              c.memberNumber == memberNumber &&
              c.collectionDate.isAfter(startOfMonth) &&
              c.collectionDate.isBefore(endOfMonth),
        )
        .fold(0.0, (sum, c) => sum + c.netWeight);
  }

  Future<List<dynamic>> getPairedDevices() async {
    try {
      return [];
    } catch (e) {
      print('Error getting paired devices: $e');
      return [];
    }
  }

  Future<bool> connectPrinter(dynamic device) async {
    try {
      connectedPrinter.value = device;
      return true;
    } catch (e) {
      print('Error connecting to printer: $e');
      return false;
    }
  }

  Future<bool> printCoffeeCollectionReceipt(CoffeeCollection collection) async {
    try {
      if (!await _checkPrintingPermissions()) return false;

      final formattedDate = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(collection.collectionDate);

      final settingsService = Get.find<SettingsService>();
      final orgSettings = settingsService.organizationSettings.value;

      final coffeeCollectionService = Get.find<CoffeeCollectionService>();
      final seasonSummary = await coffeeCollectionService
          .getMemberSeasonSummary(collection.memberId);

      double allTimeCumulativeWeight = 0.0;
      try {
        final rawWeight = seasonSummary['allTimeWeight'];
        if (rawWeight != null) {
          allTimeCumulativeWeight =
              double.tryParse(rawWeight.toString()) ?? 0.0;
        }
        if (allTimeCumulativeWeight < 0 ||
            allTimeCumulativeWeight.isNaN ||
            allTimeCumulativeWeight.isInfinite) {
          allTimeCumulativeWeight = 0.0;
        }
      } catch (e) {
        allTimeCumulativeWeight = 0.0;
      }

      final logoPath = orgSettings.logoPath;
      String? verifiedLogoPath;
      if (logoPath != null) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) verifiedLogoPath = logoPath;
      }

      final receiptData = {
        'societyName': orgSettings.societyName,
        'factory': orgSettings.factory,
        'societyAddress': orgSettings.address,
        'phoneNumber': orgSettings.phoneNumber,
        'receiptNumber': collection.receiptNumber ?? 'N/A',
        'date': formattedDate,
        'memberNumber': collection.memberNumber,
        'memberName': collection.memberName,
        'productType': collection.productType,
        'seasonName': collection.seasonName,
        'grossWeight': collection.grossWeight.toStringAsFixed(1),
        'tareWeightPerBag':
            collection.numberOfBags > 0
                ? (collection.tareWeight / collection.numberOfBags)
                    .toStringAsFixed(1)
                : '0.0',
        'totalTareWeight': collection.tareWeight.toStringAsFixed(1),
        'netWeight': collection.netWeight.toStringAsFixed(1),
        'numberOfBags': collection.numberOfBags.toString(),
        'entryType':
            collection.isManualEntry ? 'Manual Entry' : 'Scale Reading',
        'servedBy': collection.userName ?? 'N/A',
        'allTimeCumulativeWeight': allTimeCumulativeWeight.toStringAsFixed(1),
        'logoPath': verifiedLogoPath,
        'slogan': orgSettings.slogan,
        'type': 'coffee_collection',
      };

      if (printMethod.value == 'bluetooth') {
        await _printViaBluetoothPrinter(receiptData, 1);
      } else {
        await _printViaDirectPrinter(receiptData, 1);
      }

      return true;
    } catch (e) {
      print('Error printing coffee collection receipt: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print receipt: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<bool> printInventorySaleReceipt(Sale sale) async {
    try {
      if (!await _checkPrintingPermissions()) return false;

      final formattedDate = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(sale.saleDate);

      final settingsService = Get.find<SettingsService>();
      final orgSettings = settingsService.organizationSettings.value;

      final inventoryService = Get.find<InventoryService>();
      final cumulativeCredit = await inventoryService.getMemberSeasonCredit(
        sale.memberId!,
      );

      final memberService = Get.find<MemberService>();
      final member = await memberService.getMemberById(sale.memberId!);

      final logoPath = orgSettings.logoPath;
      String? verifiedLogoPath;
      if (logoPath != null) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) verifiedLogoPath = logoPath;
      }

      final receiptData = {
        'societyName': orgSettings.societyName,
        'factory': orgSettings.factory,
        'societyAddress': orgSettings.address,
        'phoneNumber': orgSettings.phoneNumber,
        'receiptNumber': sale.receiptNumber ?? 'N/A',
        'date': formattedDate,
        'memberNumber': member?.memberNumber ?? 'N/A',
        'memberName': sale.memberName ?? 'N/A',
        'saleType': sale.saleType,
        'seasonName': sale.seasonName ?? 'Current Season',
        'totalAmount': sale.totalAmount.toStringAsFixed(2),
        'paidAmount': sale.paidAmount.toStringAsFixed(2),
        'balanceAmount': sale.balanceAmount.toStringAsFixed(2),
        'cumulativeCredit': cumulativeCredit.toStringAsFixed(2),
        'servedBy': sale.userName ?? 'N/A',
        'logoPath': verifiedLogoPath,
        'slogan': orgSettings.slogan,
        'type': 'inventory_sale',
        'notes': sale.notes,
      };

      int copiesToPrint = 1;
      try {
        copiesToPrint = settingsService.systemSettings.value.receiptDuplicates;
      } catch (e) {
        copiesToPrint = 1;
      }

      if (printMethod.value == 'bluetooth') {
        await _printViaBluetoothPrinter(receiptData, copiesToPrint);
      } else {
        await _printViaDirectPrinter(receiptData, copiesToPrint);
      }

      return true;
    } catch (e) {
      print('Error printing inventory sale receipt: $e');
      Get.snackbar(
        'Print Error',
        'Failed to print receipt: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    }
  }

  Future<bool> _ensureLocationPermissionForFeature(String featureName) async {
    if (_permissionService != null) {
      return await _permissionService!.ensureLocationPermissionForFeature(
        featureName,
      );
    }
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text('$featureName Requires Permissions'),
        content: const Text(
          'This feature requires permissions to work properly. '
          'Please enable required permissions in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}