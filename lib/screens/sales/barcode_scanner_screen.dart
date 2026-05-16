import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  late MobileScannerController _cameraController;

  // 🛡️ VERROU GLOBAL (empêche les scans multiples)
  static bool _globalLock = false;

  bool _flashOn = false;
  bool _detected = false;
  bool _isCleaningUp = false;
  String _detectedCode = '';
  String _detectedFormat = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _globalLock = false;

    _cameraController = MobileScannerController(
      // ⚡ Vitesse maximale pour les petits codes
      detectionSpeed: DetectionSpeed.unrestricted,
      facing: CameraFacing.back,
      torchEnabled: false,
      autoStart: true,
      // ✅ SUPPRIMER LE FILTRE DE FORMATS
      // → Supporte TOUS les types de codes-barres
      // EAN13, EAN8, UPC-A, UPC-E, Code128, Code39,
      // Code93, Codabar, ITF, QR, DataMatrix, etc.
    );
  }

  @override
  void dispose() {
    _isCleaningUp = true;
    WidgetsBinding.instance.removeObserver(this);
    try {
      _cameraController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isCleaningUp) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      try {
        _cameraController.stop();
      } catch (_) {}
    } else if (state == AppLifecycleState.resumed) {
      if (!_globalLock && !_detected) {
        try {
          _cameraController.start();
        } catch (_) {}
      }
    }
  }

  // =============================================
  //     CALLBACK DE DÉTECTION (ULTRA PROTÉGÉ)
  // =============================================

  void _handleDetection(BarcodeCapture capture) {
    if (_globalLock) return;
    if (_detected) return;
    if (_isCleaningUp) return;
    if (!mounted) return;

    if (capture.barcodes.isEmpty) return;

    // Prendre le premier code valide
    final barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;

    if (code == null || code.trim().isEmpty) return;

    // Nettoyer le code (espaces, caractères parasites)
    final cleanCode = code.trim();

    // 🔒 VERROUILLER
    _globalLock = true;
    _detected = true;
    _detectedCode = cleanCode;
    _detectedFormat = _formatName(barcode.format);

    // Vibration
    HapticFeedback.heavyImpact();

    // Mettre à jour l'UI
    if (mounted) setState(() {});

    // Fermer et retourner
    _closeAndReturn(cleanCode);
  }

  // =============================================
  //     NOM DU FORMAT DE CODE-BARRES
  // =============================================

  String _formatName(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.ean13:
        return 'EAN-13';
      case BarcodeFormat.ean8:
        return 'EAN-8';
      case BarcodeFormat.upcA:
        return 'UPC-A';
      case BarcodeFormat.upcE:
        return 'UPC-E';
      case BarcodeFormat.code128:
        return 'Code 128';
      case BarcodeFormat.code39:
        return 'Code 39';
      case BarcodeFormat.code93:
        return 'Code 93';
      case BarcodeFormat.codabar:
        return 'Codabar';
      case BarcodeFormat.itf:
        return 'ITF';
      case BarcodeFormat.qrCode:
        return 'QR Code';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      case BarcodeFormat.pdf417:
        return 'PDF417';
      case BarcodeFormat.aztec:
        return 'Aztec';
      default:
        return 'Code-barres';
    }
  }

  // =============================================
  //     FERMETURE SÉCURISÉE
  // =============================================

  Future<void> _closeAndReturn(String code) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    try {
      await _cameraController.stop();
    } catch (_) {}

    if (!mounted) return;
    Navigator.of(context).pop(code);
  }

  // =============================================
  //     TOGGLE FLASH
  // =============================================

  void _toggleFlash() {
    if (_detected || _isCleaningUp) return;
    try {
      _cameraController.toggleTorch();
      setState(() => _flashOn = !_flashOn);
    } catch (_) {}
  }

  // =============================================
  //     RETOUR MANUEL
  // =============================================

  void _goBack() {
    _globalLock = true;
    _detected = true;
    try {
      _cameraController.stop();
    } catch (_) {}
    Navigator.of(context).pop();
  }

  // =============================================
  //               BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
                    // ---- CAMÉRA ----
          MobileScanner(
            controller: _cameraController,
            onDetect: _handleDetection,
            fit: BoxFit.cover,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off,
                          color: Colors.white54, size: 60),
                      const SizedBox(height: 16),
                      const Text(
                        'Impossible d\'accéder à la caméra',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Veuillez autoriser l\'accès à la caméra\ndans les paramètres du téléphone',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Retour'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ---- OVERLAY ----
          _buildScanOverlay(),

          // ---- EN-TÊTE ----
          _buildHeader(),

          // ---- BAS ----
          _buildBottom(),
        ],
      ),
    );
  }

  // =============================================
  //        OVERLAY CADRE DE SCAN
  // =============================================

  Widget _buildScanOverlay() {
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Container(color: Colors.black.withOpacity(0.55)),
        ),
        Row(
          children: [
            Expanded(
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
            SizedBox(
              width: 280,
              height: 180,
              child: Stack(
                children: [
                  ..._buildCorners(),
                  if (!_detected) _buildScanLine(),
                  if (_detected) _buildDetectedBadge(),
                ],
              ),
            ),
            Expanded(
              child: Container(color: Colors.black.withOpacity(0.55)),
            ),
          ],
        ),
        Expanded(
          flex: 3,
          child: Container(color: Colors.black.withOpacity(0.55)),
        ),
      ],
    );
  }

  List<Widget> _buildCorners() {
    const s = 30.0;
    const w = 4.0;
    final c = _detected ? Colors.green : Colors.indigo.shade400;

    return [
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: c, width: w),
                left: BorderSide(color: c, width: w)),
            borderRadius:
                const BorderRadius.only(topLeft: Radius.circular(12)),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: c, width: w),
                right: BorderSide(color: c, width: w)),
            borderRadius:
                const BorderRadius.only(topRight: Radius.circular(12)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: c, width: w),
                left: BorderSide(color: c, width: w)),
            borderRadius:
                const BorderRadius.only(bottomLeft: Radius.circular(12)),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: s,
          height: s,
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: c, width: w),
                right: BorderSide(color: c, width: w)),
            borderRadius:
                const BorderRadius.only(bottomRight: Radius.circular(12)),
          ),
        ),
      ),
    ];
  }

  Widget _buildScanLine() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Positioned(
          top: value * 160,
          left: 10,
          right: 10,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                Colors.indigo.shade400,
                Colors.transparent,
              ]),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.6),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && !_detected && !_globalLock) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildDetectedBadge() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      _detectedCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Format: $_detectedFormat',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================
  //                EN-TÊTE
  // =============================================

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: _goBack,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scanner un produit',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  Text(
                      'Placez le code-barres dans le cadre',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            GestureDetector(
              onTap: _toggleFlash,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _flashOn
                      ? Colors.amber.withOpacity(0.8)
                      : Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _flashOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================================
  //               BAS
  // =============================================

  Widget _buildBottom() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _tip(Icons.center_focus_strong,
                        'Centrez le code-barres dans le cadre'),
                    const SizedBox(height: 10),
                    _tip(Icons.light_mode_outlined,
                        'Assurez-vous d\'avoir un bon éclairage'),
                    const SizedBox(height: 10),
                    _tip(Icons.zoom_in,
                        'Rapprochez le téléphone pour les petits codes'),
                    const SizedBox(height: 10),
                    _tip(Icons.touch_app_outlined,
                        'Maintenez le téléphone stable'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _showManualEntry,
                  icon: const Icon(Icons.keyboard, size: 22),
                  label: const Text('SAISIE MANUELLE DU CODE',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(
                        color: Colors.white54, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo.shade200, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13)),
        ),
      ],
    );
  }

  // =============================================
  //          SAISIE MANUELLE
  // =============================================

  void _showManualEntry() {
    if (_globalLock) return;

    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.keyboard, color: Colors.indigo.shade600),
            const SizedBox(width: 10),
            const Text('Saisie manuelle',
                style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le code-barres du produit :',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.text,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '000000000',
                hintStyle: TextStyle(
                    color: Colors.grey.shade300,
                    letterSpacing: 3,
                    fontSize: 22),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.indigo.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                      color: Colors.indigo.shade400, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);

                _globalLock = true;
                _detected = true;
                _detectedCode = code;
                _detectedFormat = 'Manuel';

                if (mounted) setState(() {});
                _closeAndReturn(code);
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Valider'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}