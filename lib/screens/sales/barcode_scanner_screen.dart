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
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
    // Formats supportés (optimise la détection)
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE, BarcodeFormat.code128, BarcodeFormat.code39],
  );

  // 🛡️ PROTECTION ANTI-DOUBLE DÉTECTION
  bool _isProcessing = false;
  bool _isDisposed = false;
  String? _lastScannedCode;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    // Arrêter proprement la caméra
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Gérer le cycle de vie de l'app (mise en arrière-plan, etc.)
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      cameraController.stop();
    } else if (state == AppLifecycleState.resumed) {
      cameraController.start();
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    // 🛡️ 1. Protection : Déjà en cours de traitement ?
    if (_isProcessing) return;

    // 🛡️ 2. Protection : Widget déjà disposé ?
    if (_isDisposed || !mounted) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // 🛡️ 3. Protection : Anti-rebond (même code scanné il y a moins de 2 sec)
    final now = DateTime.now();
    if (_lastScannedCode == code && 
        _lastScanTime != null && 
        now.difference(_lastScanTime!).inSeconds < 2) {
      return;
    }

    // 🛡️ 4. Verrouiller le traitement
    _isProcessing = true;
    _lastScannedCode = code;
    _lastScanTime = now;

    // Vibration de confirmation
    HapticFeedback.heavyImpact();

    // Arrêter la caméra pour économiser les ressources et arrêter la détection
    cameraController.stop();

    // Retourner le code
    if (mounted) {
      Navigator.pop(context, code);
    }
  }

  void _toggleFlash() {
    if (_isDisposed) return;
    try {
      cameraController.toggleTorch();
      setState(() {}); // Pour mettre à jour l'icône si besoin
    } catch (e) {
      debugPrint('Erreur flash: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ---- CAMÉRA ----
          MobileScanner(
            controller: cameraController,
            onDetect: _onBarcodeDetected,
            // Ligne importante : fit pour bien remplir l'écran
            fit: BoxFit.cover,
          ),

          // ---- OVERLAY AVEC CADRE DE SCAN ----
          _buildScanOverlay(),

          // ---- EN-TÊTE ----
          _buildHeader(),

          // ---- INSTRUCTIONS EN BAS ----
          _buildBottomInstructions(),
        ],
      ),
    );
  }

  // =============================================
  //        OVERLAY AVEC CADRE ANIMÉ
  // =============================================

  Widget _buildScanOverlay() {
    return Column(
      children: [
        // Haut
        Expanded(
          flex: 2,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
        // Centre avec cadre
        Row(
          children: [
            // Gauche
            Expanded(
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
            // Cadre de scan
            SizedBox(
              width: 280,
              height: 180,
              child: Stack(
                children: [
                  // Coins
                  ..._buildCornerBorders(),
                  // Ligne de scan animée seulement si pas en traitement
                  if (!_isProcessing) _buildScanLine(),
                ],
              ),
            ),
            // Droite
            Expanded(
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ],
        ),
        // Bas
        Expanded(
          flex: 3,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
      ],
    );
  }

  List<Widget> _buildCornerBorders() {
    const double cornerSize = 30;
    const double cornerWidth = 4;
    final color = _isProcessing ? Colors.green : Colors.indigo.shade400;

    return [
      // Coin haut-gauche
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: cornerWidth),
              left: BorderSide(color: color, width: cornerWidth),
            ),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
          ),
        ),
      ),
      // Coin haut-droit
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: color, width: cornerWidth),
              right: BorderSide(color: color, width: cornerWidth),
            ),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
          ),
        ),
      ),
      // Coin bas-gauche
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: cornerWidth),
              left: BorderSide(color: color, width: cornerWidth),
            ),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
          ),
        ),
      ),
      // Coin bas-droit
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: color, width: cornerWidth),
              right: BorderSide(color: color, width: cornerWidth),
            ),
            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
          ),
        ),
      ),
      // Message "Scanné !"
      if (_isProcessing)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Code détecté !',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
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
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.indigo.shade400.withOpacity(0.8),
                  Colors.indigo.shade400,
                  Colors.indigo.shade400.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        // Relancer l'animation seulement si pas en traitement et widget monté
        if (mounted && !_isProcessing && !_isDisposed) {
          setState(() {});
        }
      },
    );
  }

  // =============================================
  //                EN-TÊTE
  // =============================================

  Widget _buildHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Bouton retour
            GestureDetector(
              onTap: () {
                cameraController.stop();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Titre
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanner un produit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Placez le code-barres dans le cadre',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            // Bouton Flash
            GestureDetector(
              onTap: _toggleFlash,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cameraController.value.torchState == TorchState.on
                      ? Colors.amber.withOpacity(0.8)
                      : Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  cameraController.value.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
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
  //          INSTRUCTIONS EN BAS
  // =============================================

  Widget _buildBottomInstructions() {
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
              // Conseils
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _tipRow(Icons.center_focus_strong,
                        'Centrez le code-barres dans le cadre'),
                    const SizedBox(height: 10),
                    _tipRow(Icons.light_mode_outlined,
                        'Assurez-vous d\'avoir un bon éclairage'),
                    const SizedBox(height: 10),
                    _tipRow(Icons.touch_app_outlined,
                        'Maintenez le téléphone stable'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bouton saisie manuelle
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _showManualEntry,
                  icon: const Icon(Icons.keyboard, size: 22),
                  label: const Text(
                    'SAISIE MANUELLE DU CODE',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.indigo.shade200, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // =============================================
  //          SAISIE MANUELLE DU CODE
  // =============================================

  void _showManualEntry() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.keyboard, color: Colors.indigo.shade600),
            const SizedBox(width: 10),
            const Text('Saisie manuelle', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Entrez le code-barres du produit manuellement :',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 3),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '000000000',
                hintStyle: TextStyle(
                    color: Colors.grey.shade300,
                    letterSpacing: 3,
                    fontSize: 22),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.indigo.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.indigo.shade400, width: 2),
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
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx); // Fermer le dialog
                // Simuler une détection
                _onBarcodeDetected(BarcodeCapture(barcodes: [
                  Barcode(rawValue: code, format: BarcodeFormat.unknown)
                ]));
              }
            },
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Valider'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}