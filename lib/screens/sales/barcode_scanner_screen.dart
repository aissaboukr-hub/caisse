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

  // Controller de la caméra
  late MobileScannerController _cameraController;

  // 🛡️ VERROU GLOBAL (hors du cycle de vie du widget)
  static bool _globalLock = false;

  // État local pour l'UI
  bool _flashOn = false;
  bool _detected = false;
  String _detectedCode = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      autoStart: true,
    );

    // Réinitialiser le verrou global
    _globalLock = false;
  }

  @override
  void dispose() {
    _isCleaningUp = true;
    WidgetsBinding.instance.removeObserver(this);

    // Disposer le controller de manière sûre
    try {
      _cameraController.dispose();
    } catch (_) {}

    super.dispose();
  }

  bool _isCleaningUp = false;

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
  //    CALLBACK DE DÉTECTION (ULTRA PROTÉGÉ)
  // =============================================

  void _handleDetection(BarcodeCapture capture) {
    // 🛡️ Vérification 1 : Verrou global déjà activé ?
    if (_globalLock) return;

    // 🛡️ Vérification 2 : Déjà détecté localement ?
    if (_detected) return;

    // 🛡️ Vérification 3 : Nettoyage en cours ?
    if (_isCleaningUp) return;

    // 🛡️ Vérification 4 : Widget monté ?
    if (!mounted) return;

    // Extraire le code
    if (capture.barcodes.isEmpty) return;
    final String? code = capture.barcodes.first.rawValue;
    if (code == null || code.trim().isEmpty) return;

    // 🔒 ACTIVER LE VERROU GLOBAL IMMÉDIATEMENT (synchrone)
    _globalLock = true;
    _detected = true;
    _detectedCode = code;

    // Vibration
    HapticFeedback.heavyImpact();

    // Mettre à jour l'UI (le cadre devient vert)
    if (mounted) {
      setState(() {});
    }

    // Arrêter la caméra puis fermer l'écran
    _closeAndReturn(code);
  }

  // =============================================
  //    FERMETURE SÉCURISÉE
  // =============================================

  Future<void> _closeAndReturn(String code) async {
    // Petit délai pour montrer le feedback visuel "Détecté !"
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // Arrêter la caméra proprement
    try {
      await _cameraController.stop();
    } catch (_) {}

    if (!mounted) return;

    // Retourner le code
    Navigator.of(context).pop(code);
  }

  // =============================================
  //    TOGGLE FLASH
  // =============================================

  void _toggleFlash() {
    if (_detected || _isCleaningUp) return;
    try {
      _cameraController.toggleTorch();
      setState(() => _flashOn = !_flashOn);
    } catch (_) {}
  }

  // =============================================
  //    RETOUR MANUEL
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 50),
                    const SizedBox(height: 16),
                    Text(
                      'Erreur caméra:\n${error.toString()}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Retour'),
                    ),
                  ],
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
            border: Border(top: BorderSide(color: c, width: w), left: BorderSide(color: c, width: w)),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
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
            border: Border(top: BorderSide(color: c, width: w), right: BorderSide(color: c, width: w)),
            borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
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
            border: Border(bottom: BorderSide(color: c, width: w), left: BorderSide(color: c, width: w)),
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
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
            border: Border(bottom: BorderSide(color: c, width: w), right: BorderSide(color: c, width: w)),
            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(12)),
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 6),
                Text(
                  '$_detectedCode',
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
                  Text('Placez le code-barres dans le cadre',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                    side: const BorderSide(color: Colors.white54, width: 1.5),
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
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
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
            const Text('Saisie manuelle', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Entrez le code-barres du produit :',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
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
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);

                _globalLock = true;
                _detected = true;
                _detectedCode = code;

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