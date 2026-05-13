import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  MobileScannerController cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isDetected = false;
  bool _flashOn = false;
  String? _lastCode;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_isDetected) return; // Empêcher double détection

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isDetected = true;
      _lastCode = code;
    });

    // Vibration + retour avec le code
    Navigator.pop(context, code);
  }

  void _toggleFlash() {
    setState(() => _flashOn = !_flashOn);
    cameraController.toggleTorch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ---- CAMÉRA EN ARRIÈRE-PLAN ----
          MobileScanner(
            controller: cameraController,
            onDetect: _onBarcodeDetected,
          ),

          // ---- OVERLAY SOMBRE AVEC FENTRE DE SCAN ----
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
  //        OVERLAY AVEC FENTRE DE SCAN
  // =============================================

  Widget _buildScanOverlay() {
    return Column(
      children: [
        // Partie sombre au-dessus
        Expanded(
          flex: 2,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),

        // Zone centrale de scan
        Row(
          children: [
            // Partie sombre à gauche
            Expanded(
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),

            // Fenêtre de scan
            Container(
              width: 280,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.transparent,
                ),
              ),
              child: Stack(
                children: [
                  // Coins animés
                  ..._buildCornerBorders(),

                  // Ligne de scan animée
                  if (!_isDetected) _buildScanLine(),
                ],
              ),
            ),

            // Partie sombre à droite
            Expanded(
              child: Container(color: Colors.black.withOpacity(0.6)),
            ),
          ],
        ),

        // Partie sombre en dessous
        Expanded(
          flex: 3,
          child: Container(color: Colors.black.withOpacity(0.6)),
        ),
      ],
    );
  }

  // =============================================
  //           CORNERS DU CADRE DE SCAN
  // =============================================

  List<Widget> _buildCornerBorders() {
    const double cornerSize = 30;
    const double cornerWidth = 4;
    final color = _isDetected ? Colors.green : Colors.indigo.shade400;

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

      // Message "Détecté !" au centre
      if (_isDetected)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      'Code: $_lastCode',
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

  // =============================================
  //           LIGNE DE SCAN ANIMÉE
  // =============================================

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
            height: 3,
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
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
      onEnd: () {
        // Boucler l'animation
        if (mounted && !_isDetected) {
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
              onTap: () => Navigator.pop(context),
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
                  onPressed: () => _showManualEntry(),
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
                Navigator.pop(context, code); // Retourner le code
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