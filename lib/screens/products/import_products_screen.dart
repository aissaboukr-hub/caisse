import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/product_model.dart';
import '../../services/import_service.dart';
import '../../services/product_service.dart';

class ImportProductsScreen extends StatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  State<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends State<ImportProductsScreen> {
  final ImportService _importService = ImportService();
  final ProductService _productService = ProductService();
  final TextEditingController _urlController = TextEditingController();

  // État
  String _selectedMethod = ''; // 'excel' ou 'gsheet'
  bool _isLoading = false;
  bool _replaceAll = true;
  String _statusMessage = '';
  List<ProductModel> _previewProducts = [];
  bool _showPreview = false;
  String? _fileName;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // =============================================
  //          IMPORT DEPUIS EXCEL
  // =============================================

  Future<void> _pickExcelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final filePath = result.files.single.path;
      if (filePath == null) {
        _showSnackBar('❌ Impossible d\'accéder au fichier', isError: true);
        return;
      }

      setState(() {
        _isLoading = true;
        _fileName = result.files.single.name;
        _statusMessage = 'Lecture du fichier Excel...';
        _showPreview = false;
        _previewProducts = [];
      });

      // Parser le fichier
      final products = await _importService.importFromExcel(filePath);

      setState(() {
        _isLoading = false;
        _previewProducts = products;
        _showPreview = true;
        _statusMessage = '${products.length} produits trouvés';
      });

      if (products.isEmpty) {
        _showSnackBar('⚠️ Aucun produit trouvé dans le fichier',
            isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Erreur: $e';
      });
      _showSnackBar('❌ Erreur: $e', isError: true);
    }
  }

  // =============================================
  //       IMPORT DEPUIS GOOGLE SHEETS
  // =============================================

  Future<void> _fetchGoogleSheet() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      _showSnackBar('⚠️ Entrez l\'URL du Google Sheet', isError: true);
      return;
    }

    if (!url.contains('docs.google.com/spreadsheets')) {
      _showSnackBar('⚠️ URL Google Sheets invalide', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connexion à Google Sheets...';
      _showPreview = false;
      _previewProducts = [];
    });

    try {
      final products = await _importService.importFromGoogleSheets(url);

      setState(() {
        _isLoading = false;
        _previewProducts = products;
        _showPreview = true;
        _statusMessage = '${products.length} produits trouvés';
        _fileName = 'Google Sheets';
      });

      if (products.isEmpty) {
        _showSnackBar('⚠️ Aucun produit trouvé dans la feuille',
            isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Erreur: $e';
      });
      _showSnackBar('❌ $e', isError: true);
    }
  }

  // =============================================
  //        CONFIRMER L'IMPORT
  // =============================================

  Future<void> _confirmImport() async {
    if (_previewProducts.isEmpty) {
      _showSnackBar('⚠️ Aucun produit à importer', isError: true);
      return;
    }

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(Icons.download_done, color: Colors.indigo.shade600),
            const SizedBox(width: 10),
            const Text('Confirmer l\'import'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_previewProducts.length} produits seront importés.',
              style: const TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (_replaceAll)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber,
                        color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Les produits existants seront supprimés !',
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline,
                        color: Colors.green.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Les produits seront ajoutés aux existants.',
                        style: TextStyle(
                            color: Colors.green.shade700, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Importer'),
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

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Import en cours...';
    });

    try {
      final added = await _productService.importProducts(
        _previewProducts,
        replaceAll: _replaceAll,
      );

      setState(() {
        _isLoading = false;
        _statusMessage = '✅ $added produits importés avec succès !';
        _showPreview = false;
        _previewProducts = [];
      });

      _showSnackBar('✅ $added produits importés !', isError: false);

      // Retourner à l'écran précédent après 1.5 sec
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.pop(context, true);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Erreur: $e';
      });
      _showSnackBar('❌ Erreur lors de l\'import: $e', isError: true);
    }
  }

  // =============================================
  //              SNACKBAR
  // =============================================

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =============================================
  //               BUILD
  // =============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'Importer des Produits',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- GUIDE DU FORMAT ----
            _buildFormatGuide(),
            const SizedBox(height: 20),

            // ---- CHOIX DE LA MÉTHODE ----
            _buildMethodSelector(),
            const SizedBox(height: 20),

            // ---- ZONE DE SÉLECTION (selon la méthode) ----
            if (_selectedMethod == 'excel') _buildExcelSection(),
            if (_selectedMethod == 'gsheet') _buildGoogleSheetsSection(),
            if (_selectedMethod.isNotEmpty) const SizedBox(height: 16),

            // ---- LOADING ----
            if (_isLoading) _buildLoading(),

            // ---- STATUS ----
            if (_statusMessage.isNotEmpty && !_isLoading)
              _buildStatusBar(),
            const SizedBox(height: 16),

            // ---- MODE D'IMPORT ----
            if (_showPreview) _buildImportMode(),
            if (_showPreview) const SizedBox(height: 16),

            // ---- APERÇU ----
            if (_showPreview) _buildPreview(),
            if (_showPreview) const SizedBox(height: 20),

            // ---- BOUTON IMPORTER ----
            if (_showPreview) _buildImportButton(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // =============================================
  //          GUIDE DU FORMAT ATTENDU
  // =============================================

  Widget _buildFormatGuide() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: Colors.indigo.shade600, size: 22),
              const SizedBox(width: 10),
              Text(
                'Format attendu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tableau d'exemple
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                    Colors.indigo.shade600),
                headingTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                dataTextStyle: TextStyle(
                    color: Colors.grey.shade800, fontSize: 12),
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Nom')),
                  DataColumn(label: Text('Catégorie')),
                  DataColumn(label: Text('Prix')),
                  DataColumn(label: Text('Stock')),
                  DataColumn(label: Text('Unité')),
                  DataColumn(label: Text('Code-barres')),
                ],
                rows: [
                  _exampleRow('Coca-Cola 1L', 'Boissons', '3500', '50',
                      'piece', '5449000000996'),
                  _exampleRow('Riz 5Kg', 'Alimentation', '12000', '20',
                      'piece', '6111028000050'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          Text(
            '• La première ligne doit contenir les en-têtes\n'
            '• Les colonnes "Nom" et "Prix" sont obligatoires\n'
            '• Les noms de colonnes en français ou anglais sont acceptés\n'
            '• Formats acceptés: .xlsx, .xls, Google Sheets',
            style: TextStyle(
                color: Colors.grey.shade600, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  DataRow _exampleRow(
      String nom, String cat, String prix, String stock,
      String unit, String code) {
    return DataRow(cells: [
      DataCell(Text(nom)),
      DataCell(Text(cat)),
      DataCell(Text(prix)),
      DataCell(Text(stock)),
      DataCell(Text(unit)),
      DataCell(Text(code)),
    ]);
  }

  // =============================================
  //         SÉLECTEUR DE MÉTHODE
  // =============================================

  Widget _buildMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Source des données',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Excel
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMethod = 'excel';
                    _showPreview = false;
                    _previewProducts = [];
                    _statusMessage = '';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: _selectedMethod == 'excel'
                        ? Colors.green.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedMethod == 'excel'
                          ? Colors.green.shade400
                          : Colors.grey.shade200,
                      width: _selectedMethod == 'excel' ? 2 : 1,
                    ),
                    boxShadow: _selectedMethod == 'excel'
                        ? [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.table_chart_rounded,
                        size: 40,
                        color: _selectedMethod == 'excel'
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Fichier Excel',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _selectedMethod == 'excel'
                              ? Colors.green.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '.xlsx / .xls',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (_selectedMethod == 'excel')
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(Icons.check_circle,
                              color: Colors.green.shade400, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Google Sheets
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedMethod = 'gsheet';
                    _showPreview = false;
                    _previewProducts = [];
                    _statusMessage = '';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: _selectedMethod == 'gsheet'
                        ? Colors.blue.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selectedMethod == 'gsheet'
                          ? Colors.blue.shade400
                          : Colors.grey.shade200,
                      width: _selectedMethod == 'gsheet' ? 2 : 1,
                    ),
                    boxShadow: _selectedMethod == 'gsheet'
                        ? [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 40,
                        color: _selectedMethod == 'gsheet'
                            ? Colors.blue.shade600
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Google Sheets',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _selectedMethod == 'gsheet'
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'En ligne',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      if (_selectedMethod == 'gsheet')
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Icon(Icons.check_circle,
                              color: Colors.blue.shade400, size: 18),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // =============================================
  //        SECTION EXCEL
  // =============================================

  Widget _buildExcelSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Fichier sélectionné ?
          if (_fileName != null && !_isLoading)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.insert_drive_file,
                      color: Colors.green.shade600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _fileName!,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  Icon(Icons.check_circle, color: Colors.green.shade400),
                ],
              ),
            ),

          // Bouton sélectionner fichier
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _pickExcelFile,
              icon: const Icon(Icons.folder_open_rounded, size: 24),
              label: Text(
                _fileName == null
                    ? 'SÉLECTIONNER UN FICHIER EXCEL'
                    : 'CHOISIR UN AUTRE FICHIER',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //       SECTION GOOGLE SHEETS
  // =============================================

  Widget _buildGoogleSheetsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'URL du Google Sheet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),

          // Champ URL
          TextField(
            controller: _urlController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText:
                  'https://docs.google.com/spreadsheets/d/...',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: Icon(Icons.link,
                  color: Colors.blue.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.blue.shade400, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Aide
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.lightbulb_outline,
                    color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le Google Sheet doit être partagé avec\n'
                    '"Tous les détenteurs du lien"',
                    style: TextStyle(
                        color: Colors.amber.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bouton récupérer
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _fetchGoogleSheet,
              icon: const Icon(Icons.cloud_download_rounded, size: 24),
              label: const Text(
                'RÉCUPÉRER LES DONNÉES',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //              LOADING
  // =============================================

  Widget _buildLoading() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              color: Colors.indigo.shade600,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _statusMessage,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //          BARRE DE STATUT
  // =============================================

  Widget _buildStatusBar() {
    final isSuccess = _statusMessage.contains('✅');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSuccess ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSuccess
              ? Colors.green.shade200
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.info_outline,
            color:
                isSuccess ? Colors.green.shade600 : Colors.orange.shade600,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMessage,
              style: TextStyle(
                color: isSuccess
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //         MODE D'IMPORT (Ajouter/Remplacer)
  // =============================================

  Widget _buildImportMode() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.settings_outlined,
                  color: Colors.indigo.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Mode d\'import',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Option : Remplacer
          GestureDetector(
            onTap: () => setState(() => _replaceAll = true),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _replaceAll
                    ? Colors.red.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _replaceAll
                      ? Colors.red.shade300
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: _replaceAll,
                    activeColor: Colors.red,
                    onChanged: (v) =>
                        setState(() => _replaceAll = v ?? true),
                  ),
                  Icon(Icons.delete_sweep_outlined,
                      color: _replaceAll
                          ? Colors.red.shade600
                          : Colors.grey.shade400,
                      size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Remplacer tout',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _replaceAll
                                ? Colors.red.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Supprimer les anciens produits et importer les nouveaux',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Option : Ajouter
          GestureDetector(
            onTap: () => setState(() => _replaceAll = false),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: !_replaceAll
                    ? Colors.green.shade50
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: !_replaceAll
                      ? Colors.green.shade300
                      : Colors.grey.shade200,
                ),
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: _replaceAll,
                    activeColor: Colors.green,
                    onChanged: (v) =>
                        setState(() => _replaceAll = v ?? false),
                  ),
                  Icon(Icons.add_circle_outline,
                      color: !_replaceAll
                          ? Colors.green.shade600
                          : Colors.grey.shade400,
                      size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ajouter aux existants',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: !_replaceAll
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          'Conserver les produits actuels et ajouter les nouveaux',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =============================================
  //            APERÇU DES DONNÉES
  // =============================================

  Widget _buildPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(Icons.preview_outlined,
                    color: Colors.indigo.shade600, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Aperçu (${_previewProducts.length} produits)',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          // Tableau
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(Colors.indigo.shade600),
              headingTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              dataTextStyle:
                  TextStyle(color: Colors.grey.shade800, fontSize: 12),
              columnSpacing: 14,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 42,
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Nom')),
                DataColumn(label: Text('Catégorie')),
                DataColumn(label: Text('Prix')),
                DataColumn(label: Text('Stock')),
                DataColumn(label: Text('Code-barres')),
              ],
              rows: _previewProducts.take(20).toList().asMap().entries.map(
                (entry) {
                  final i = entry.key;
                  final p = entry.value;
                  return DataRow(
                    color: WidgetStateProperty.all(
                      i.isEven
                          ? Colors.grey.shade50
                          : Colors.white,
                    ),
                    cells: [
                      DataCell(Text('${i + 1}',
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11))),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            p.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      DataCell(_categoryBadge(p.category)),
                      DataCell(Text(
                        '${p.price.toStringAsFixed(0)} FC',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.indigo.shade700,
                        ),
                      )),
                      DataCell(Text(
                        '${p.stock}',
                        style: TextStyle(
                          color: p.stock <= 5
                              ? Colors.red.shade600
                              : Colors.grey.shade700,
                          fontWeight: p.stock <= 5
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      )),
                      DataCell(Text(
                        p.barcode ?? '-',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                      )),
                    ],
                  );
                },
              ).toList(),
            ),
          ),

          // Si plus de 20 produits
          if (_previewProducts.length > 20)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  '... et ${_previewProducts.length - 20} autres produits',
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _categoryBadge(String category) {
    Color color;
    switch (category) {
      case 'Boissons':
        color = Colors.blue;
        break;
      case 'Alimentation':
        color = Colors.orange;
        break;
      case 'Hygiène':
        color = Colors.purple;
        break;
      case 'Confiserie':
        color = Colors.pink;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        category,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  // =============================================
  //          BOUTON IMPORTER
  // =============================================

  Widget _buildImportButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _confirmImport,
        icon: const Icon(Icons.download_rounded, size: 26),
        label: Text(
          'IMPORTER ${_previewProducts.length} PRODUITS',
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.shade300,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
          shadowColor: Colors.indigo.withOpacity(0.4),
        ),
      ),
    );
  }
}