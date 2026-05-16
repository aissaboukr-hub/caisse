import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService extends ChangeNotifier {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal() {
    _init();
  }

  String? _selectedDeviceAddress;
  String? _selectedDeviceName;
  bool _isConnected = false;
  bool _isScanning = false;
  String _statusMessage = 'Non connecté';
  int _paperSize = 80;

  List<Map<String, String>> _devices = [];

  // =============================================
  //               GETTERS
  // =============================================

  List<Map<String, String>> get devices => _devices;
  String? get selectedDeviceName => _selectedDeviceName;
  String? get selectedDeviceAddress => _selectedDeviceAddress;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String get statusMessage => _statusMessage;
  int get paperSize => _paperSize;

  // =============================================
  //          INITIALISATION
  // =============================================

  Future<void> _init() async {
    try {
      _isConnected = await PrintBluetoothThermal.connectionStatus;
      _statusMessage = _isConnected ? 'Connecté' : 'Non connecté';

      await _loadSavedDevice();

      if (_isConnected && _selectedDeviceAddress != null) {
        _statusMessage = 'Connecté à $_selectedDeviceName';
      }
    } catch (e) {
      debugPrint('Erreur init printer: $e');
    }
    notifyListeners();
  }

  // =============================================
  //          SAUVEGARDE / CHARGEMENT
  // =============================================

  static const String _addressKey = 'printer_device_address';
  static const String _nameKey = 'printer_device_name';
  static const String _paperSizeKey = 'printer_paper_size';

  Future<void> _saveDevice(String address, String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_addressKey, address);
      await prefs.setString(_nameKey, name);
    } catch (e) {
      debugPrint('Erreur sauvegarde device: $e');
    }
  }

  Future<void> _loadSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selectedDeviceAddress = prefs.getString(_addressKey);
      _selectedDeviceName = prefs.getString(_nameKey);
      _paperSize = prefs.getInt(_paperSizeKey) ?? 80;
    } catch (e) {
      debugPrint('Erreur chargement device: $e');
    }
  }

  Future<void> setPaperSize(int size) async {
    _paperSize = size;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_paperSizeKey, size);
    notifyListeners();
  }

  // =============================================
  //          SCAN DES APPAREILS
  // =============================================

  Future<void> scanDevices() async {
    _isScanning = true;
    _statusMessage = 'Recherche d\'imprimantes...';
    notifyListeners();

    try {
      final List<BluetoothInfo> bluetoothDevices =
          await PrintBluetoothThermal.pairedBluetooths;

      _devices = bluetoothDevices.map((device) {
        return {
          'name': device.name ?? 'Appareil inconnu',
          'address': device.macAdress ?? '',
        };
      }).toList();

      _statusMessage = '${_devices.length} appareil(s) trouvé(s)';
    } catch (e) {
      _statusMessage = 'Erreur: $e';
      debugPrint('Erreur scan: $e');
    }

    _isScanning = false;
    notifyListeners();
  }

  // =============================================
  //          CONNEXION / DÉCONNEXION
  // =============================================

  Future<bool> connect(String address, String name) async {
    _statusMessage = 'Connexion à $name...';
    notifyListeners();

    try {
      final bool result =
          await PrintBluetoothThermal.connect(macPrinterAddress: address);

      if (result) {
        _isConnected = true;
        _selectedDeviceAddress = address;
        _selectedDeviceName = name;
        _statusMessage = 'Connecté à $name';
        await _saveDevice(address, name);
        notifyListeners();
        return true;
      } else {
        _isConnected = false;
        _statusMessage = 'Échec de connexion';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _isConnected = false;
      _statusMessage = 'Erreur de connexion: $e';
      debugPrint('Erreur connexion: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected = false;
      _selectedDeviceAddress = null;
      _selectedDeviceName = null;
      _statusMessage = 'Déconnecté';
    } catch (e) {
      debugPrint('Erreur déconnexion: $e');
    }
    notifyListeners();
  }

  // =============================================
  //          CONNEXION AUTO
  // =============================================

  Future<bool> autoConnect() async {
    if (_selectedDeviceAddress == null) return false;
    if (_isConnected) return true;
    return await connect(
        _selectedDeviceAddress!, _selectedDeviceName ?? 'Imprimante');
  }

  // =============================================
  //     IMPRIMER UN TICKET DE VENTE
  // =============================================

  Future<bool> printTicket({
    required String ticketId,
    required String date,
    required String cashierName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    required double amountPaid,
    required double change,
    String shopName = 'Ma Caisse',
    String? shopAddress,
    String? shopPhone,
  }) async {
    // Vérifier la connexion
    if (!_isConnected) {
      final connected = await autoConnect();
      if (!connected) {
        _statusMessage = 'Aucune imprimante connectée';
        notifyListeners();
        return false;
      }
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(
        _paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80,
        profile,
      );

      List<int> bytes = [];

      // ═══ EN-TÊTE ═══
      bytes += generator.text(
        shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if (shopAddress != null && shopAddress.isNotEmpty) {
        bytes += generator.text(
          shopAddress,
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      if (shopPhone != null && shopPhone.isNotEmpty) {
        bytes += generator.text(
          'Tel: $shopPhone',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      bytes += generator.hr();

      bytes += generator.text(
        'Date: $date',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Caissier: $cashierName',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Ticket: #$ticketId',
        styles: const PosStyles(align: PosAlign.left),
      );

      bytes += generator.hr();

      // ═══ ARTICLES ═══
      if (_paperSize == 80) {
        bytes += generator.row([
          PosColumn(
            text: 'QTÉ',
            width: 2,
            styles:
                const PosStyles(bold: true, align: PosAlign.center),
          ),
          PosColumn(
            text: 'DÉSIGNATION',
            width: 5,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: 'P.U.',
            width: 2,
            styles:
                const PosStyles(bold: true, align: PosAlign.right),
          ),
          PosColumn(
            text: 'TOTAL',
            width: 3,
            styles:
                const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]);
      } else {
        bytes += generator.row([
          PosColumn(
            text: 'QTE',
            width: 2,
            styles:
                const PosStyles(bold: true, align: PosAlign.center),
          ),
          PosColumn(
            text: 'ARTICLE',
            width: 6,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: 'TOTAL',
            width: 4,
            styles:
                const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr(ch: '-');

      for (final item in items) {
        final name = item['name'] as String;
        final qty = item['quantity'] as int;
        final price = item['price'] as double;
        final total = item['total'] as double;

        if (_paperSize == 80) {
          bytes += generator.row([
            PosColumn(
              text: 'x$qty',
              width: 2,
              styles: const PosStyles(align: PosAlign.center),
            ),
            PosColumn(
              text: name,
              width: 5,
              styles: const PosStyles(),
            ),
            PosColumn(
              text: price.toStringAsFixed(0),
              width: 2,
              styles: const PosStyles(align: PosAlign.right),
            ),
            PosColumn(
              text: total.toStringAsFixed(0),
              width: 3,
              styles:
                  const PosStyles(align: PosAlign.right, bold: true),
            ),
          ]);
        } else {
          bytes += generator.text(
            'x$qty $name',
            styles: const PosStyles(),
          );
          bytes += generator.text(
            '  ${price.toStringAsFixed(0)} x $qty = ${total.toStringAsFixed(0)} DZ',
            styles: const PosStyles(align: PosAlign.right),
          );
        }
      }

      bytes += generator.hr();

      // ═══ TOTAL ═══
      bytes += generator.text(
        'TOTAL: ${totalAmount.toStringAsFixed(0)} DZ',
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      bytes += generator.text(
        'Payé: ${amountPaid.toStringAsFixed(0)} DZ',
        styles: const PosStyles(align: PosAlign.right),
      );

      bytes += generator.text(
        'Monnaie: ${change.toStringAsFixed(0)} DZ',
        styles: const PosStyles(align: PosAlign.right),
      );

      bytes += generator.hr();

      // ═══ PIED DE PAGE ═══
      bytes += generator.text(
        'Merci pour votre achat !',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );

      bytes += generator.text(
        'À bientôt !',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.feed(3);
      bytes += generator.cut();

      // ═══ ENVOYER À L'IMPRIMANTE ═══
      final bool result =
          await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        _statusMessage = 'Ticket imprimé ✅';
        notifyListeners();
        return true;
      } else {
        _statusMessage = 'Erreur d\'envoi';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _statusMessage = 'Erreur d\'impression: $e';
      debugPrint('Erreur impression: $e');
      notifyListeners();
      return false;
    }
  }

  // =============================================
  //     IMPRIMER UN TEST
  // =============================================

  Future<bool> printTest() async {
    if (!_isConnected) {
      final connected = await autoConnect();
      if (!connected) return false;
    }

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(
        _paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80,
        profile,
      );

      List<int> bytes = [];

      bytes += generator.text(
        'TEST D\'IMPRESSION',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      bytes += generator.hr();

      bytes += generator.text(
        'Imprimante: ${_selectedDeviceName ?? "Inconnue"}',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.text(
        'Papier: ${_paperSize}mm',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.text(
        'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} '
        '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        styles: const PosStyles(align: PosAlign.center),
      );

      bytes += generator.hr();

      bytes += generator.text(
        'Connexion OK !',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      );

      bytes += generator.feed(3);
      bytes += generator.cut();

      final bool result =
          await PrintBluetoothThermal.writeBytes(bytes);

      if (result) {
        _statusMessage = 'Test imprimé ✅';
        notifyListeners();
        return true;
      } else {
        _statusMessage = 'Erreur test';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _statusMessage = 'Erreur test: $e';
      notifyListeners();
      return false;
    }
  }
}