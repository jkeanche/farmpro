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

// Remove the export since PrinterInfo is not available in this version

// Define print method enum
enum PrintMethod { bluetooth, direct }

class PrintService extends GetxService {
  static PrintService get to => Get.find();

  PermissionService? _permissionService;

  // Track the current print method
  final Rx<PrintMethod> currentPrintMethod = PrintMethod.bluetooth.obs;

  // Available printers
  final RxList<dynamic> availablePrinters = <dynamic>[].obs;

  // Selected printer for direct printing
  final Rx<dynamic> selectedPrinter = Rx<dynamic>(null);

  // Print method preference
  RxString printMethod = 'bluetooth'.obs;

  // Connected printer - using dynamic type instead of specific BluetoothDevice type
  Rx<dynamic> connectedPrinter = Rx<dynamic>(null);

  Future<PrintService> init() async {
    // Initialize PermissionService with fallback
    try {
      _permissionService = Get.find<PermissionService>();
    } catch (e) {
      print('Warning: PermissionService not found, continuing without it: $e');
      // Continue without permission service - it will be null
    }

    // Discover available printers with error handling
    await discoverPrinters();

    // Load any previously saved default printer first
    await loadSavedDefaultPrinter();

    // Ensure system default printer is selected if no saved preference
    if (selectedPrinter.value == null) {
      await ensureSystemDefaultPrinter();
    }

    return this;
  }

  // Check if printing is available on this platform
  bool get isPrintingAvailable {
    try {
      // Try to access the printing plugin
      return availablePrinters.isNotEmpty || selectedPrinter.value != null;
    } catch (e) {
      return false;
    }
  }

  // Show a user-friendly message when printing is not available
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

  // Discover available printers for direct printing
  Future<void> discoverPrinters() async {
    try {
      final printers = await Printing.listPrinters();
      availablePrinters.value = printers;

      // Find the system default printer
      dynamic defaultPrinter = _findDefaultPrinter(printers);

      // Set default printer if available, or use first printer as fallback
      if (defaultPrinter != null) {
        selectedPrinter.value = defaultPrinter;
        print('System default printer set: ${defaultPrinter.name}');
      } else if (printers.isNotEmpty && selectedPrinter.value == null) {
        selectedPrinter.value = printers.first;
        print(
          'No default printer found, using first available: ${printers.first.name}',
        );
      }
    } on MissingPluginException catch (e) {
      print('Printing plugin not available on this platform: $e');
      // Set empty list to indicate no printers available
      availablePrinters.value = [];
    } catch (e) {
      print('Error discovering printers: $e');
      availablePrinters.value = [];
    }
  }

  // Helper method to find the system default printer
  dynamic _findDefaultPrinter(List<dynamic> printers) {
    try {
      // Look for a printer marked as default
      for (var printer in printers) {
        // Try to access isDefault property safely
        try {
          if (printer?.isDefault == true) {
            return printer;
          }
        } catch (e) {
          // isDefault property doesn't exist, continue
        }

        // Try to check for name containing "default" (case insensitive)
        try {
          if (printer?.name != null &&
              printer.name.toLowerCase().contains('default')) {
            return printer;
          }
        } catch (e) {
          // name property access failed, continue
        }
      }

      // If no explicit default found, the first printer is usually the system default
      if (printers.isNotEmpty) {
        return printers.first;
      }
    } catch (e) {
      print('Error finding default printer: $e');
    }
    return null;
  }

  // Get system default printer specifically
  Future<dynamic> getSystemDefaultPrinter() async {
    try {
      final printers = await Printing.listPrinters();
      return _findDefaultPrinter(printers);
    } on MissingPluginException catch (e) {
      print('Printing plugin not available on this platform: $e');
      return null;
    } catch (e) {
      print('Error getting system default printer: $e');
      return null;
    }
  }

  // Ensure system default printer is used
  Future<void> ensureSystemDefaultPrinter() async {
    try {
      final defaultPrinter = await getSystemDefaultPrinter();
      if (defaultPrinter != null) {
        selectedPrinter.value = defaultPrinter;
        print('System default printer ensured: ${defaultPrinter.name}');

        // Save the default printer preference
        await _saveDefaultPrinterPreference(defaultPrinter);
      } else {
        print('No system default printer available');
      }
    } catch (e) {
      print('Error ensuring system default printer: $e');
    }
  }

  // Save default printer preference to settings
  Future<void> _saveDefaultPrinterPreference(dynamic printer) async {
    try {
      if (printer != null && printer.name != null) {
        final settingsService = Get.find<SettingsService>();
        await settingsService.saveSetting('default_printer_name', printer.name);
        print('Default printer preference saved: ${printer.name}');
      }
    } catch (e) {
      print('Error saving default printer preference: $e');
    }
  }

  // Load and set saved default printer
  Future<void> loadSavedDefaultPrinter() async {
    try {
      final settingsService = Get.find<SettingsService>();
      final savedPrinterName = await settingsService.getSetting(
        'default_printer_name',
      );

      if (savedPrinterName != null && availablePrinters.isNotEmpty) {
        // Find the saved printer in available printers
        for (var printer in availablePrinters) {
          try {
            if (printer?.name == savedPrinterName) {
              selectedPrinter.value = printer;
              print('Loaded saved default printer: $savedPrinterName');
              return;
            }
          } catch (e) {
            // Continue if error accessing printer properties
          }
        }
        print(
          'Saved printer "$savedPrinterName" not found in available printers',
        );
      }
    } catch (e) {
      print('Error loading saved default printer: $e');
    }
  }

  // Set the print method using string values
  void setPrintMethod(String method) {
    printMethod.value = method;

    if (method == 'bluetooth') {
      currentPrintMethod.value = PrintMethod.bluetooth;
    } else {
      currentPrintMethod.value = PrintMethod.direct;
    }
  }

  // Set the selected printer
  void setSelectedPrinter(dynamic printer) {
    selectedPrinter.value = printer;

    // Save this as the new default preference
    _saveDefaultPrinterPreference(printer);
  }

  // Refresh printers and automatically select system default
  Future<void> refreshAndSelectDefaultPrinter() async {
    try {
      print('Refreshing printers and selecting system default...');

      // Rediscover printers
      await discoverPrinters();

      // Force selection of system default printer
      await ensureSystemDefaultPrinter();

      print('Printer refresh completed');
    } catch (e) {
      print('Error refreshing printers: $e');
    }
  }

  // Check necessary permissions based on printing method
  Future<bool> _checkPrintingPermissions() async {
    if (!Platform.isAndroid) return true;

    if (currentPrintMethod.value == PrintMethod.bluetooth) {
      // Check Bluetooth permissions first
      bool hasBluetoothPermission = false;
      if (_permissionService != null) {
        hasBluetoothPermission =
            await _permissionService!.checkBluetoothPermission();
      }
      if (!hasBluetoothPermission) {
        // Check if location is needed for Bluetooth (common on Android)
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

        // Request Bluetooth permission
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

    // For all printing methods, we need storage access for PDF generation
    bool hasStoragePermission = false;
    if (_permissionService != null) {
      hasStoragePermission = await _permissionService!.checkStoragePermission();
    }
    if (!hasStoragePermission) {
      print('Requesting storage permission for printing...');
      Get.snackbar(
        'Storage Permission Required',
        'Storage access is needed to generate and save receipts',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Request the permission
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

  // Print receipt
  Future<void> printReceipt(Map<String, dynamic> receiptData) async {
    // Check permissions first
    if (!await _checkPrintingPermissions()) {
      return;
    }

    // For direct printing, ensure we're using the system default printer
    if (currentPrintMethod.value == PrintMethod.direct) {
      await ensureSystemDefaultPrinter();
    }

    // Check if this is an inventory sale receipt and get number of copies
    final isInventorySale = receiptData['type'] == 'sale';
    int copiesToPrint = 1;

    if (isInventorySale) {
      try {
        final settingsService = Get.find<SettingsService>();
        copiesToPrint = settingsService.systemSettings.value.receiptDuplicates;
        print(
          '📄 Receipt copies setting: $copiesToPrint (type: ${receiptData['type']})',
        );
      } catch (e) {
        print('Error getting receipt duplicates setting: $e');
        copiesToPrint = 1; // Default to single copy on error
      }
    } else {
      print(
        '📄 Not an inventory sale receipt (type: ${receiptData['type']}), using 1 copy',
      );
    }

    // Print with the specified number of copies
    if (currentPrintMethod.value == PrintMethod.bluetooth) {
      await _printViaBluetoothPrinter(receiptData, copiesToPrint);
    } else {
      await _printViaDirectPrinter(receiptData, copiesToPrint);
    }
  }

  // Print using Bluetooth printer - simplified version
  Future<void> _printViaBluetoothPrinter(
    Map<String, dynamic> receiptData,
    int copies,
  ) async {
    try {
      // In a real implementation, this would connect to a Bluetooth printer
      // For now, we'll just show the print dialog
      final pdf = await _generateReceiptPdf(receiptData, copies: copies);

      try {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf,
          name: 'Receipt',
        );
      } on MissingPluginException catch (e) {
        print('Printing plugin not available: $e');
        _showPrintingNotAvailableMessage();
        return;
      }

      // Get.snackbar(
      //   'Success',
      //   'Receipt prepared for printing',
      //   snackPosition: SnackPosition.BOTTOM,
      //   backgroundColor: Colors.green,
      //   colorText: Colors.white
      // );
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

  // Print using direct printer connection via printing package
  Future<void> _printViaDirectPrinter(
    Map<String, dynamic> receiptData,
    int copies,
  ) async {
    try {
      if (selectedPrinter.value == null) {
        throw Exception('No printer selected for direct printing');
      }

      // Create PDF document with specified number of copies
      final pdf = await _generateReceiptPdf(receiptData, copies: copies);

      // Print directly to selected printer
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

  // Generate PDF for receipt
  Future<Uint8List> _generateReceiptPdf(
    Map<String, dynamic> receiptData, {
    int copies = 1,
  }) async {
    print('📄 _generateReceiptPdf called with copies=$copies');
    final pdf = pw.Document();

    // Get current date and time with proper formatting
    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);

    // Load logo if available - improved debugging
    pw.MemoryImage? logoImage;
    print('Logo path in receiptData: ${receiptData['logoPath']}');

    if (receiptData['logoPath'] != null &&
        receiptData['logoPath'].toString().isNotEmpty) {
      try {
        final String logoPath = receiptData['logoPath'].toString();
        print('Attempting to load logo from path: $logoPath');

        // Verify the file exists
        final File logoFile = File(logoPath);
        final bool fileExists = await logoFile.exists();
        print('Logo file exists: $fileExists');

        if (fileExists) {
          // Check file size
          final int fileSize = await logoFile.length();
          print('Logo file size: $fileSize bytes');

          if (fileSize > 0) {
            try {
              final logoBytes = await logoFile.readAsBytes();
              print(
                'Successfully read ${logoBytes.length} bytes from logo file',
              );

              // Create image from bytes
              logoImage = pw.MemoryImage(logoBytes);
              print('Logo image created successfully for PDF');
            } catch (readError) {
              print('Error reading logo file bytes: $readError');
            }
          } else {
            print('Logo file exists but is empty (0 bytes)');
          }
        } else {
          print('Logo file does not exist at path: $logoPath');

          // Try to list files in the directory to help debugging
          try {
            final directory = Directory(
              logoPath.substring(0, logoPath.lastIndexOf('/')),
            );
            if (await directory.exists()) {
              print('Contents of directory: ${directory.path}');
              final List<FileSystemEntity> files =
                  await directory.list().toList();
              for (var file in files) {
                print(' - ${file.path}');
              }
            } else {
              print('Parent directory does not exist');
            }
          } catch (dirError) {
            print('Error listing directory: $dirError');
          }
        }
      } catch (e) {
        print('Error in logo loading process: $e');
      }
    } else {
      print('No logo path provided in receipt data or path is empty');
    }

    // Create PDF content with custom page format for optimal 80mm receipt width
    // Generate the specified number of copies (pages)
    print('📄 Starting PDF page generation loop: copies=$copies');
    for (int copyNumber = 0; copyNumber < copies; copyNumber++) {
      print('📄 Adding page ${copyNumber + 1} of $copies');
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80.copyWith(
            marginLeft: 10,
            marginRight: 10,
            marginTop: 4,
            marginBottom: 4,
          ),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Logo if available - Optimized for 80mm receipt width
                if (logoImage != null) ...[
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Container(
                      height: 80,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
                  ),
                  pw.SizedBox(height: 6),
                ],

                // Header
                pw.Center(
                  child: pw.Text(
                    receiptData['societyName'] ?? 'Farm Fresh',
                    style: pw.TextStyle(
                      fontSize: 21,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),

                // Factory name
                if (receiptData['factory'] != null)
                  pw.Center(
                    child: pw.Text(
                      receiptData['factory'],
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),

                // Society address
                if (receiptData['societyAddress'] != null)
                  pw.Center(
                    child: pw.Text(
                      receiptData['societyAddress'],
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  ),

                pw.SizedBox(height: 6),

                // Current date and time (when printed)
                pw.Center(
                  child: pw.Text(
                    'Printed on: $formattedDate at $formattedTime',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),

                pw.SizedBox(height: 10),

                // Receipt number
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Receipt #:',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                    pw.Text(
                      receiptData['receiptNumber'] ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  ],
                ),

                // Divider
                pw.Divider(),

                // Member info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Member:', style: const pw.TextStyle(fontSize: 13)),
                    pw.Text(
                      receiptData['memberName'] ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Member #:',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                    pw.Text(
                      receiptData['memberNumber'] ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  ],
                ),

                // Collection/Delivery Date (the actual date when collection happened)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      receiptData['type'] == 'coffee_collection'
                          ? 'Collection Date:'
                          : 'Delivery Date:',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                    pw.Text(
                      receiptData['date'] ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  ],
                ),

                // Served By - Always display this field prominently
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Served By:',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                    pw.Text(
                      receiptData['servedBy'] ?? 'N/A',
                      style: const pw.TextStyle(fontSize: 13),
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                // Coffee Collection Details (Coffee Type and Season)
                if (receiptData['type'] == 'coffee_collection') ...[
                  pw.Container(
                    width: double.infinity,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'COFFEE COLLECTION DETAILS',
                          style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Table(
                          border: null,
                          columnWidths: const {
                            0: pw.FlexColumnWidth(3),
                            1: pw.FlexColumnWidth(2),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Text(
                                  'Coffee Type:',
                                  style: pw.TextStyle(
                                    fontSize: 17,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: pw.BoxDecoration(
                                    color: PdfColors.grey200,
                                    borderRadius: pw.BorderRadius.circular(3),
                                  ),
                                  child: pw.Text(
                                    receiptData['productType'] ?? 'N/A',
                                    style: pw.TextStyle(
                                      fontSize: 17,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                    textAlign: pw.TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Text(
                                  'Season:',
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  receiptData['seasonName'] ?? 'N/A',
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Text(
                                  'Number of Bags:',
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.Text(
                                  receiptData['numberOfBags'] ?? 'N/A',
                                  style: pw.TextStyle(
                                    fontSize: 16,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                  textAlign: pw.TextAlign.right,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                ],

                // Details section: show sales items for 'sale' receipts, otherwise weight details
                if (receiptData['type'] == 'sale') ...[
                  //==================== ITEMS TABLE ====================
                  pw.Text(
                    'ITEMS',
                    style: pw.TextStyle(
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Table(
                    border: null,
                    columnWidths: const {
                      0: pw.FlexColumnWidth(4), // Item name
                      1: pw.FlexColumnWidth(2), // Qty
                      2: pw.FlexColumnWidth(2), // Price
                      3: pw.FlexColumnWidth(2), // Total
                    },
                    children: [
                      // Header row
                      pw.TableRow(
                        children: [
                          pw.Text(
                            'Item',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            'Qty',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                          pw.Text(
                            'Price',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                          pw.Text(
                            'Total',
                            style: pw.TextStyle(
                              fontSize: 15,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.right,
                          ),
                        ],
                      ),
                      // Data rows
                      ...((receiptData['items'] as List).map<pw.TableRow>((
                        item,
                      ) {
                        return pw.TableRow(
                          children: [
                            pw.Text(
                              item['productName'],
                              style: const pw.TextStyle(fontSize: 14),
                            ),
                            pw.Text(
                              item['quantity'],
                              style: const pw.TextStyle(fontSize: 14),
                              textAlign: pw.TextAlign.right,
                            ),
                            pw.Text(
                              item['unitPrice'],
                              style: const pw.TextStyle(fontSize: 14),
                              textAlign: pw.TextAlign.right,
                            ),
                            pw.Text(
                              item['totalPrice'],
                              style: const pw.TextStyle(fontSize: 14),
                              textAlign: pw.TextAlign.right,
                            ),
                          ],
                        );
                      })),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Divider(thickness: 0.5),
                  //==================== TOTALS ====================
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Subtotal:',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        receiptData['totalAmount'] ?? '0.00',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Paid:', style: const pw.TextStyle(fontSize: 13)),
                      pw.Text(
                        receiptData['paidAmount'] ?? '0.00',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                  if (receiptData['saleType'] == 'CREDIT' &&
                      (double.tryParse(receiptData['balanceAmount'] ?? '0') ??
                              0) >
                          0) ...[
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'This Sale Balance:',
                          style: const pw.TextStyle(fontSize: 13),
                        ),
                        pw.Text(
                          receiptData['balanceAmount'] ?? '0.00',
                          style: const pw.TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Total Balance:',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          'KSh ${receiptData['totalBalance'] ?? '0.00'}',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Sale Mode:',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                      pw.Text(
                        receiptData['saleType'] ?? 'N/A',
                        style: const pw.TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ] else ...[
                  //==================== EXISTING WEIGHT DETAILS ====================
                  pw.Container(
                    width: double.infinity,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'WEIGHT DETAILS',
                          style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 5),
                        pw.Table(
                          border: null,
                          columnWidths: const {
                            0: pw.FlexColumnWidth(3),
                            1: pw.FlexColumnWidth(2),
                          },
                          children: [
                            if (receiptData['grossWeight'] != null &&
                                receiptData['totalTareWeight'] != null) ...[
                              pw.TableRow(
                                children: [
                                  pw.Text(
                                    'Gross Weight:',
                                    style: const pw.TextStyle(fontSize: 13),
                                  ),
                                  pw.Text(
                                    '${receiptData['grossWeight']} kg',
                                    style: const pw.TextStyle(fontSize: 13),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ],
                              ),
                              if (receiptData['tareWeightPerBag'] != null) ...[
                                pw.TableRow(
                                  children: [
                                    pw.Text(
                                      'Tare Weight per Bag:',
                                      style: const pw.TextStyle(fontSize: 14),
                                    ),
                                    pw.Text(
                                      '${receiptData['tareWeightPerBag']} kg',
                                      style: const pw.TextStyle(fontSize: 14),
                                      textAlign: pw.TextAlign.right,
                                    ),
                                  ],
                                ),
                              ],
                              pw.TableRow(
                                children: [
                                  pw.Text(
                                    'Total Tare Weight:',
                                    style: const pw.TextStyle(fontSize: 13),
                                  ),
                                  pw.Text(
                                    '${receiptData['totalTareWeight']} kg',
                                    style: const pw.TextStyle(fontSize: 13),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ],
                              ),
                              pw.TableRow(
                                children: [
                                  pw.Text(
                                    'Net Weight:',
                                    style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                    '${receiptData['netWeight']} kg',
                                    style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ],
                              ),
                            ] else ...[
                              pw.TableRow(
                                children: [
                                  pw.Text(
                                    'Weight:',
                                    style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  pw.Text(
                                    '${receiptData['weight'] ?? 'N/A'} kg',
                                    style: pw.TextStyle(
                                      fontSize: 16,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                    textAlign: pw.TextAlign.right,
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Current season cumulative weight for coffee collections
                if (receiptData['type'] == 'coffee_collection' &&
                    receiptData['allTimeCumulativeWeight'] != null) ...[
                  pw.Divider(thickness: 0.5),
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    padding: const pw.EdgeInsets.all(5),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Season Total:',
                          style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${receiptData['allTimeCumulativeWeight']} kg',
                          style: pw.TextStyle(
                            fontSize: 17,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 5),
                ] else if (receiptData['cumulativeWeight'] != null) ...[
                  // Monthly cumulative weight for coffee/generic deliveries
                  pw.Divider(thickness: 0.5),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Month-to-date Total:',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        '${receiptData['cumulativeWeight']} kg',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                ],

                // Divider
                pw.Divider(),

                // Recipient information for inventory/non-collection receipts
                if (receiptData['type'] != 'coffee_collection') ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'RECEIVED BY',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'ID No: _____________________',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        flex: 2,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Sign: _____________________',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 0.5),
                ],

                // Footer
                pw.Center(
                  child: pw.Text(
                    receiptData['slogan'] ?? 'Thank you!',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),

                // Company info
                pw.Center(
                  child: pw.Text(
                    'A product of Inuka Technologies',
                    style: const pw.TextStyle(fontSize: 8),
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

  // Print receipt with a printer dialog for user selection
  Future<void> printReceiptWithDialog(Map<String, dynamic> receiptData) async {
    // Check permissions first
    if (!await _checkPrintingPermissions()) {
      return;
    }

    try {
      // Check if this is an inventory sale receipt and get number of copies
      final isInventorySale = receiptData['type'] == 'sale';
      int copiesToPrint = 1;

      if (isInventorySale) {
        try {
          final settingsService = Get.find<SettingsService>();
          copiesToPrint =
              settingsService.systemSettings.value.receiptDuplicates;
          print(
            '📄 [Dialog] Receipt copies setting: $copiesToPrint (type: ${receiptData['type']})',
          );
        } catch (e) {
          print('Error getting receipt duplicates setting: $e');
          copiesToPrint = 1; // Default to single copy on error
        }
      } else {
        print(
          '📄 [Dialog] Not an inventory sale receipt (type: ${receiptData['type']}), using 1 copy',
        );
      }

      // Generate PDF with multiple pages if needed
      print('📄 [Dialog] Generating PDF with $copiesToPrint copies');
      final pdf = await _generateReceiptPdf(receiptData, copies: copiesToPrint);

      // Show print dialog with optimized format for 80mm receipt
      try {
        await Printing.layoutPdf(
          onLayout: (_) => pdf,
          name: 'Receipt ${receiptData['receiptNumber'] ?? ''}',
          format: PdfPageFormat.roll80.copyWith(
            marginLeft: 4,
            marginRight: 4,
            marginTop: 4,
            marginBottom: 4,
          ),
        );
      } on MissingPluginException catch (e) {
        print('Printing plugin not available: $e');
        _showPrintingNotAvailableMessage();
        return;
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

  // Method to save PDF to external storage
  Future<String?> saveReceiptToPdf(Map<String, dynamic> receiptData) async {
    try {
      print('Checking storage permission for saving PDF...');
      // Check and request storage permissions
      bool hasPermission = false;
      if (_permissionService != null) {
        hasPermission = await _permissionService!.checkStoragePermission();
      }
      if (!hasPermission) {
        print(
          'Permission not granted initially, requesting storage permission',
        );
        if (_permissionService != null) {
          hasPermission = await _permissionService!.requestStoragePermission();
        }
        if (!hasPermission) {
          print('Failed to get storage permission after request');
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

      // Try with a different directory strategy depending on the outcome
      Directory? directory;
      String filePath;

      try {
        print('Attempting to use downloads directory');
        directory = await getExternalStorageDirectory();
      } catch (e) {
        print(
          'Error getting external directory: $e, falling back to documents directory',
        );
        directory = await getApplicationDocumentsDirectory();
      }

      print('Using directory: ${directory?.path ?? 'null'}');

      // Create a receipts directory if it doesn't exist
      Directory receiptsDir = Directory('${directory?.path ?? ''}/receipts');
      if (!await receiptsDir.exists()) {
        print('Creating receipts directory');
        await receiptsDir.create(recursive: true);
      }

      // Generate a unique filename based on date and receipt data
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String memberNumber = receiptData['memberNumber'] ?? 'unknown';
      filePath = '${receiptsDir.path}/receipt_${memberNumber}_$timestamp.pdf';

      print('Saving PDF to: $filePath');

      // Generate the PDF document
      final pdf = await _generateReceiptPdf(receiptData);

      // Save the PDF to the file
      final file = File(filePath);
      await file.writeAsBytes(pdf);

      print('PDF saved successfully');
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

  // Calculate monthly total for coffee collections for a member
  double calculateCoffeeMonthlyTotal(
    List<CoffeeCollection> collections,
    String memberNumber,
  ) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final memberCollections =
        collections
            .where(
              (c) =>
                  c.memberNumber == memberNumber &&
                  c.collectionDate.isAfter(startOfMonth) &&
                  c.collectionDate.isBefore(endOfMonth),
            )
            .toList();

    double total = 0;
    for (var collection in memberCollections) {
      total += collection.netWeight;
    }

    return total;
  }

  // Below are the methods that were previously using BlueThermalPrinter, updated to use a more generic approach

  // Simple list to simulate paired devices
  Future<List<dynamic>> getPairedDevices() async {
    try {
      // In a real implementation, this would return Bluetooth devices
      // For now, we'll just return an empty list
      print(
        "Returning empty device list as BlueThermalPrinter is not available",
      );
      return [];
    } catch (e) {
      print('Error getting paired devices: $e');
      return [];
    }
  }

  // Connect to a specific printer
  Future<bool> connectPrinter(dynamic device) async {
    try {
      // In a real implementation, this would connect to a Bluetooth device
      // For now, we'll just return success and use the direct printing
      print(
        "Simulating printer connection success (direct printing will be used instead)",
      );
      connectedPrinter.value = device;
      return true;
    } catch (e) {
      print('Error connecting to printer: $e');
      return false;
    }
  }

  // Print coffee collection receipt
  Future<bool> printCoffeeCollectionReceipt(CoffeeCollection collection) async {
    try {
      // Check permissions first
      if (!await _checkPrintingPermissions()) {
        return false;
      }

      // Format the DateTime as a string
      final formattedDate = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(collection.collectionDate);

      // Get organization settings from SettingsService
      final settingsService = Get.find<SettingsService>();
      final orgSettings = settingsService.organizationSettings.value;

      // Calculate all-time cumulative weight for this member (across all seasons)
      final coffeeCollectionService = Get.find<CoffeeCollectionService>();
      final seasonSummary = await coffeeCollectionService
          .getMemberSeasonSummary(collection.memberId);

      // Ensure we have a valid cumulative weight value
      double allTimeCumulativeWeight = 0.0;
      try {
        final rawWeight = seasonSummary['allTimeWeight'];
        if (rawWeight != null) {
          allTimeCumulativeWeight =
              double.tryParse(rawWeight.toString()) ?? 0.0;
        }

        // Additional validation to ensure the weight is valid and not negative
        if (allTimeCumulativeWeight < 0 ||
            allTimeCumulativeWeight.isNaN ||
            allTimeCumulativeWeight.isInfinite) {
          allTimeCumulativeWeight = 0.0;
        }
      } catch (e) {
        print('Error parsing cumulative weight for member: $e');
        allTimeCumulativeWeight = 0.0;
      }

      // Get logo path and verify it exists
      final logoPath = orgSettings.logoPath;
      String? verifiedLogoPath;
      if (logoPath != null) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          verifiedLogoPath = logoPath;
        }
      }

      final receiptData = {
        'societyName': orgSettings.societyName,
        'factory': orgSettings.factory,
        'societyAddress': orgSettings.address,
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
                : '0.0', // Tare weight per bag
        'totalTareWeight': collection.tareWeight.toStringAsFixed(
          1,
        ), // Total tare weight (already calculated)
        'netWeight': collection.netWeight.toStringAsFixed(1),
        'numberOfBags': collection.numberOfBags.toString(),
        'entryType':
            collection.isManualEntry ? 'Manual Entry' : 'Scale Reading',
        'servedBy': collection.userName ?? 'N/A',
        'allTimeCumulativeWeight': allTimeCumulativeWeight.toStringAsFixed(
          1,
        ), // All-time cumulative weight across all seasons
        'logoPath': verifiedLogoPath,
        'slogan': orgSettings.slogan,
        'type': 'coffee_collection', // Identifier for coffee collection receipt
      };

      print(
        'Printing coffee collection receipt for ${collection.memberName} with all-time cumulative: ${allTimeCumulativeWeight.toStringAsFixed(2)} kg',
      );

      // Coffee collection receipts typically print 1 copy
      const copiesToPrint = 1;

      // Print receipt based on current method
      if (printMethod.value == 'bluetooth') {
        await _printViaBluetoothPrinter(receiptData, copiesToPrint);
      } else {
        await _printViaDirectPrinter(receiptData, copiesToPrint);
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

  /// Print inventory sale receipt with cumulative credit calculation
  Future<bool> printInventorySaleReceipt(Sale sale) async {
    try {
      // Check permissions first
      if (!await _checkPrintingPermissions()) {
        return false;
      }

      // Format the DateTime as a string
      final formattedDate = DateFormat(
        'yyyy-MM-dd HH:mm',
      ).format(sale.saleDate);

      // Get organization settings from SettingsService
      final settingsService = Get.find<SettingsService>();
      final orgSettings = settingsService.organizationSettings.value;

      // Calculate cumulative credit for this member (current inventory season only)
      final inventoryService = Get.find<InventoryService>();
      final cumulativeCredit = await inventoryService.getMemberSeasonCredit(
        sale.memberId!,
      );

      // Get member details
      final memberService = Get.find<MemberService>();
      final member = await memberService.getMemberById(sale.memberId!);

      // Get logo path and verify it exists
      final logoPath = orgSettings.logoPath;
      String? verifiedLogoPath;
      if (logoPath != null) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          verifiedLogoPath = logoPath;
        }
      }

      final receiptData = {
        'societyName': orgSettings.societyName,
        'factory': orgSettings.factory,
        'societyAddress': orgSettings.address,
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
        'type': 'inventory_sale', // Identifier for inventory sale receipt
        'notes': sale.notes,
      };

      print(
        'Printing inventory sale receipt for ${sale.memberName} with cumulative credit: KSh ${cumulativeCredit.toStringAsFixed(2)}',
      );

      // Get number of copies from system settings for inventory sales
      int copiesToPrint = 1;
      try {
        copiesToPrint = settingsService.systemSettings.value.receiptDuplicates;
      } catch (e) {
        print('Error getting receipt duplicates setting: $e');
        copiesToPrint = 1; // Default to single copy on error
      }

      // Print receipt based on current method
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

  // Helper method to handle location permission for features
  Future<bool> _ensureLocationPermissionForFeature(String featureName) async {
    if (_permissionService != null) {
      return await _permissionService!.ensureLocationPermissionForFeature(
        featureName,
      );
    } else {
      // If no permission service available, show a basic dialog
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
}
