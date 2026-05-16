import 'package:flutter/material.dart';
import '../../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printerService = PrinterService();

  @override
  void initState() {
    super.initState();
    _printerService.addListener(_onPrinterChanged);
    _printerService.scanDevices();
  }

  @override
  void dispose() {
    _printerService.removeListener(_onPrinterChanged);
    super.dispose();
  }

  void _onPrinterChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'Imprimante Thermique',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Scanner',
            onPressed: () => _printerService.scanDevices(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildPaperSizeCard(),
            const SizedBox(height: 16),
            _buildDevicesSection(),
            const SizedBox(height: 16),
            if (_printerService.isConnected) ...[
              _buildActionsCard(),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  // =============================================
  //           STATUT
  // =============================================

  Widget _buildStatusCard() {
    final isConnected = _printerService.isConnected;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isConnected
              ? [Colors.green.shade600, Colors.green.shade400]
              : [Colors.orange.shade600, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isConnected ? Colors.green : Colors.orange)
                .withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isConnected ? Icons.print : Icons.print_disabled,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Connecté' : 'Non connecté',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected
                      ? '${_printerService.selectedDeviceName ?? "Imprimante"}'
                      : 'Sélectionnez une imprimante ci-dessous',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isConnected)
            IconButton(
              icon: const Icon(Icons.bluetooth_disabled,
                  color: Colors.white),
              onPressed: () => _printerService.disconnect(),
              tooltip: 'Déconnecter',
            ),
        ],
      ),
    );
  }

  // =============================================
  //           TAILLE DU PAPIER
  // =============================================

  Widget _buildPaperSizeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.straighten,
                  color: Colors.indigo.shade600, size: 22),
              const SizedBox(width: 10),
              Text(
                'Taille du papier',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _paperSizeOption(58, '58mm', 'Petit format'),
              const SizedBox(width: 12),
              _paperSizeOption(80, '80mm', 'Standard'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paperSizeOption(
      int size, String label, String subtitle) {
    final isSelected = _printerService.paperSize == size;
    return Expanded(
      child: GestureDetector(
        onTap: () => _printerService.setPaperSize(size),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.indigo.shade50
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Colors.indigo.shade400
                  : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.receipt,
                size: 30,
                color: isSelected
                    ? Colors.indigo.shade600
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                '$size mm',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isSelected
                      ? Colors.indigo.shade700
                      : Colors.grey.shade600,
                ),
              ),
              Text(
                size == 58 ? 'Petit ticket' : 'Ticket standard',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(Icons.check_circle,
                      color: Colors.indigo.shade400, size: 18),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // =============================================
  //           APPAREILS
  // =============================================

  Widget _buildDevicesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.bluetooth_searching,
                    color: Colors.indigo.shade600, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Appareils Bluetooth',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                if (_printerService.isScanning)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.indigo.shade400,
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: () =>
                        _printerService.scanDevices(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Scanner'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.indigo.shade600,
                    ),
                  ),
              ],
            ),
          ),
          if (_printerService.devices.isEmpty &&
              !_printerService.isScanning)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.bluetooth_disabled,
                        size: 48,
                        color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun appareil trouvé',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assurez-vous que l\'imprimante est\nallumée et appairée dans les paramètres Bluetooth',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ...List.generate(
              _printerService.devices.length, (index) {
            final device = _printerService.devices[index];
            final address = device['address'] ?? '';
            final name = device['name'] ?? '';
            final isSelected =
                _printerService.selectedDeviceAddress == address;
            final isCurrentlyConnected =
                isSelected && _printerService.isConnected;

            return Container(
              margin: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentlyConnected
                    ? Colors.green.shade50
                    : isSelected
                        ? Colors.indigo.shade50
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrentlyConnected
                      ? Colors.green.shade300
                      : isSelected
                          ? Colors.indigo.shade300
                          : Colors.grey.shade200,
                ),
              ),
              child: ListTile(
                onTap: () async {
                  final success = await _printerService
                      .connect(address, name);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('✅ Connecté à $name'),
                        backgroundColor:
                            Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(12)),
                        margin: const EdgeInsets.all(12),
                      ),
                    );
                  }
                },
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isCurrentlyConnected
                        ? Colors.green.shade100
                        : Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isCurrentlyConnected
                        ? Icons.bluetooth_connected
                        : Icons.bluetooth,
                    color: isCurrentlyConnected
                        ? Colors.green.shade700
                        : Colors.indigo.shade400,
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isCurrentlyConnected
                        ? Colors.green.shade800
                        : Colors.grey.shade800,
                  ),
                ),
                subtitle: Text(
                  address,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                trailing: isCurrentlyConnected
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Connecté',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : Icon(Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey.shade400),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // =============================================
  //           ACTIONS
  // =============================================

  Widget _buildActionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_outlined,
                  color: Colors.indigo.shade600, size: 22),
              const SizedBox(width: 10),
              Text(
                'Actions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () async {
                final success =
                    await _printerService.printTest();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? '✅ Page de test imprimée'
                          : '❌ Erreur d\'impression'),
                      backgroundColor: success
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                      margin: const EdgeInsets.all(12),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.print, size: 22),
              label: const Text(
                'IMPRIMER PAGE DE TEST',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: () => _printerService.disconnect(),
              icon: const Icon(Icons.bluetooth_disabled,
                  size: 22, color: Colors.red),
              label: Text(
                'DÉCONNECTER',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade600),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}