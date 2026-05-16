import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrinterService extends ChangeNotifier {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal() {
    _init();
  }

  final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isScanning = false;
  String _statusMessage = 'Non connecté';

  // Taille du papier
  int _paperSize = 80; // 58 ou 80 mm

  // =============================================
  //               GETTERS
  // =============================================

  List<BluetoothDevice> get devices => _devices;
  BluetoothDevice? get selectedDevice => _selectedDevice;
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String get statusMessage => _statusMessage;
  int get paperSize => _paperSize;

  // =============================================
  //          INITIALISATION
  // =============================================

  Future<void> _init() async {
    try {
      _isConnected = (await _bluetooth.isConnected) ?? false;
      _statusMessage = _isConnected ? 'Connecté' : 'Non connecté';

      // Charger le device sauvegardé
      await _loadSavedDevice();

      // Écouter les changements de connexion
      _bluetooth.onStateChanged().listen((state) {
        switch (state) {
          case BlueThermalPrinter.CONNECTED:
            _isConnected = true;
            _statusMessage = 'Connecté';
            break;
          case BlueThermalPrinter.DISCONNECTED:
            _isConnected = false;
            _statusMessage = 'Déconnecté';
            _selectedDevice = null;
            break;
          default:
            break;
        }
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Erreur init printer: $e');
    }
    notifyListeners();
  }

  // =============================================
  //          SAUVEGARDE / CHARGEMENT DEVICE
  // =============================================

  static const String _deviceKey = 'printer_device_address';
  static const String _paperSizeKey = 'printer_paper_size';

  Future<void> _saveDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_deviceKey, device.address ?? '');
      await prefs.setString('${_deviceKey}_name', device.name ?? '');
    } catch (e) {
      debugPrint('Erreur sauvegarde device: $e');
    }
  }

  Future<void> _loadSavedDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final address = prefs.getString(_deviceKey);
      final name = prefs.getString('${_deviceKey}_name');
      _paperSize = prefs.getInt(_paperSizeKey) ?? 80;

      if (address != null && address.isNotEmpty) {
        _selectedDevice = BluetoothDevice(name ?? 'Imprimante', address);
      }
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
  //          SCAN DES APPAREILS BLUETOOTH
  // =============================================

  Future<void> scanDevices() async {
    _isScanning = true;
    _statusMessage = 'Recherche d\'imprimantes...';
    notifyListeners();

    try {
      _devices = await _bluetooth.getBondedDevices();
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

  Future<bool> connect(BluetoothDevice device) async {
    _statusMessage = 'Connexion à ${device.name}...';
    notifyListeners();

    try {
      await _bluetooth.connect(device);
      _isConnected = true;
      _selectedDevice = device;
      _statusMessage = 'Connecté à ${device.name}';
      await _saveDevice(device);
      notifyListeners();
      return true;
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
      await _bluetooth.disconnect();
      _isConnected = false;
      _selectedDevice = null;
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
    if (_selectedDevice == null) return false;

    if (_isConnected) return true;

    return await connect(_selectedDevice!);
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
      // Essayer la reconnexion auto
      final connected = await autoConnect();
      if (!connected) {
        _statusMessage = 'Aucune imprimante connectée';
        notifyListeners();
        return false;
      }
    }

    try {
      // Générer le profil selon la taille du papier
      final profile = await CapabilityProfile.load();
      final generator = Generator(
        _paperSize == 58 ? PaperSize.mm58 : PaperSize.mm80,
        profile,
      );

      List<int> bytes = [];

      // ═══════════════════════════════════
      //          EN-TÊTE DU TICKET
      // ═══════════════════════════════════

      // Nom de la boutique
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

      // Séparateur
      bytes += generator.hr();

      // Date et infos
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

      // ═══════════════════════════════════
      //          ARTICLES
      // ═══════════════════════════════════

      // En-tête tableau
      if (_paperSize == 80) {
        // Format 80mm : plus de place
        bytes += generator.row([
          PosColumn(
            text: 'QTÉ',
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.center),
          ),
          PosColumn(
            text: 'DÉSIGNATION',
            width: 5,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: 'P.U.',
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
          PosColumn(
            text: 'TOTAL',
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]);
      } else {
        // Format 58mm : compact
        bytes += generator.row([
          PosColumn(
            text: 'QTE',
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.center),
          ),
          PosColumn(
            text: 'ARTICLE',
            width: 6,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: 'TOTAL',
            width: 4,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]);
      }

      bytes += generator.hr(ch: '-');

      // Chaque article
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
              styles: const PosStyles(
                  align: PosAlign.right, bold: true),
            ),
          ]);
        } else {
          // 58mm : 2 lignes par article
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

      // ═══════════════════════════════════
      //          TOTAL
      // ═══════════════════════════════════

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

      // ═══════════════════════════════════
          //          PIED DE PAGE
      // ═══════════════════════════════════

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

      // Espace final et coupe du papier
      bytes += generator.feed(3);
      bytes += generator.cut();

      // ═══════════════════════════════════
      //          ENVOYER À L'IMPRIMANTE
      // ═══════════════════════════════════

      // Envoyer par paquets (certaines imprimantes ont des limites)
      const int chunkSize = 200;
      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length)
            ? i + chunkSize
            : bytes.length;
        final chunk = bytes.sublist(i, end);
        await _bluetooth.writeBytes(Uint8List.fromList(chunk));
        // Petit délai entre les paquets
        await Future.delayed(const Duration(milliseconds: 50));
      }

      _statusMessage = 'Ticket imprimé ✅';
      notifyListeners();
      return true;
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
        'Imprimante: ${_selectedDevice?.name ?? "Inconnue"}',
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

      await _bluetooth.writeBytes(Uint8List.fromList(bytes));

      _statusMessage = 'Test imprimé ✅';
      notifyListeners();
      return true;
    } catch (e) {
      _statusMessage = 'Erreur test: $e';
      notifyListeners();
      return false;
    }
  }
}