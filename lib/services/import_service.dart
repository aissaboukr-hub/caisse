import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/product_model.dart';

class ImportService {
  // Singleton
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  // =============================================
  //        IMPORT DEPUIS UN FICHIER EXCEL
  // =============================================

  Future<List<ProductModel>> importFromExcel(String filePath) async {
    try {
      // 1. Lire les bytes du fichier
      final bytes = File(filePath).readAsBytesSync();

      // 2. Décoder le fichier Excel
      final excel = Excel.decodeBytes(bytes);

      // 3. Prendre la première feuille
      if (excel.tables.isEmpty) {
        throw Exception('Le fichier Excel ne contient aucune feuille');
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('La feuille "$sheetName" est vide');
      }

      // 4. Convertir les lignes en liste de listes de String
      final List<List<String>> rows = [];
      for (final row in sheet.rows) {
        final List<String> stringRow = [];
        for (final cell in row) {
          stringRow.add(_cellToString(cell?.value));
        }
        rows.add(stringRow);
      }

      // 5. Parser les produits
      return _parseRows(rows);
    } catch (e) {
      debugPrint('Erreur import Excel: $e');
      rethrow;
    }
  }

  // =============================================
  //     IMPORT DEPUIS GOOGLE SHEETS (CSV)
  // =============================================

  Future<List<ProductModel>> importFromGoogleSheets(String url) async {
    try {
      // 1. Extraire l'ID de la feuille Google Sheets
      final sheetId = _extractSheetId(url);
      if (sheetId == null) {
        throw Exception(
          'URL Google Sheets invalide.\n'
          'Format attendu:\n'
          'https://docs.google.com/spreadsheets/d/SHEET_ID/...',
        );
      }

      // 2. Extraire le gid (feuille spécifique)
      final gid = _extractGid(url);

      // 3. Construire l'URL CSV
      final csvUrl =
          'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$gid';

      debugPrint('Téléchargement CSV: $csvUrl');

      // 4. Télécharger le CSV
      final response = await http.get(
        Uri.parse(csvUrl),
        headers: {'Accept': 'text/csv; charset=utf-8'},
      );

      if (response.statusCode != 200) {
        if (response.statusCode == 403) {
          throw Exception(
            'Accès refusé. Assurez-vous que le Google Sheet est '
            'partagé avec "Tous les détenteurs du lien".',
          );
        }
        if (response.statusCode == 404) {
          throw Exception('Google Sheet introuvable. Vérifiez l\'URL.');
        }
        throw Exception(
          'Erreur de téléchargement (code: ${response.statusCode})',
        );
      }

      // 5. Décoder le CSV
      final csvString = utf8.decode(response.bodyBytes);

      final List<List<dynamic>> csvRows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(csvString);

      // 6. Convertir en List<List<String>>
      final List<List<String>> rows = csvRows
          .map((row) => row.map((cell) => cell.toString().trim()).toList())
          .toList();

      // 7. Parser les produits
      return _parseRows(rows);
    } catch (e) {
      debugPrint('Erreur import Google Sheets: $e');
      rethrow;
    }
  }

  // =============================================
  //        PARSER LES LIGNES EN PRODUITS
  // =============================================

  List<ProductModel> _parseRows(List<List<String>> rows) {
    if (rows.isEmpty) return [];

    // 1. Détecter les colonnes depuis l'en-tête (première ligne)
    final headers = rows.first.map((h) => h.toLowerCase().trim()).toList();

    final nameIdx = _findColumn(headers, [
      'nom', 'name', 'produit', 'product', 'designation',
      'désignation', 'designation', 'libellé', 'libelle',
      'article', 'intitulé', 'intitule',
    ]);

    final catIdx = _findColumn(headers, [
      'catégorie', 'categorie', 'category', 'type',
      'famille', 'groupe',
    ]);

    final priceIdx = _findColumn(headers, [
      'prix', 'price', 'tarif', 'pu', 'montant',
      'prix unitaire', 'prix_unitaire', 'p.u',
    ]);

    final stockIdx = _findColumn(headers, [
      'stock', 'quantité', 'quantite', 'qty', 'qte',
      'quantite', 'qté', 'qtt', 'disponible',
    ]);

    final unitIdx = _findColumn(headers, [
      'unité', 'unite', 'unit', 'mesure',
    ]);

    final barcodeIdx = _findColumn(headers, [
      'code-barres', 'code_barres', 'barcode', 'code barres',
      'ean', 'code-barre', 'code_barre', 'codes', 'code',
    ]);

    debugPrint(
      'Colonnes détectées: nom=$nameIdx, cat=$catIdx, '
      'prix=$priceIdx, stock=$stockIdx, unit=$unitIdx, '
      'barcode=$barcodeIdx',
    );

    // Si pas de colonne nom trouvée, utiliser la première colonne
    final effectiveNameIdx = nameIdx >= 0 ? nameIdx : 0;

    // 2. Parcourir les données (ignorer l'en-tête)
    final List<ProductModel> products = [];
    int idCounter = DateTime.now().millisecondsSinceEpoch;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      // Ignorer les lignes vides
      if (row.isEmpty || row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }

      // Extraire les valeurs
      final name = _getCell(row, effectiveNameIdx);
      if (name.isEmpty) continue; // Ignorer si pas de nom

      final category = _getCell(row, catIdx, defaultValue: 'Divers');
      final price = _parseDouble(_getCell(row, priceIdx));
      final stock = _parseInt(_getCell(row, stockIdx, defaultValue: '0'));
      final unit = _parseUnit(_getCell(row, unitIdx));
      final barcode = _getCell(row, barcodeIdx, defaultValue: '');

      products.add(ProductModel(
        id: '${idCounter++}',
        name: name,
        category: category.isEmpty ? 'Divers' : category,
        price: price,
        stock: stock,
        unit: unit,
        barcode: barcode.isNotEmpty ? barcode : null,
        isAvailable: true,
        createdAt: DateTime.now(),
      ));
    }

    return products;
  }

  // =============================================
  //           UTILITAIRES DE PARSING
  // =============================================

  /// Trouver l'index d'une colonne parmi les en-têtes
  int _findColumn(List<String> headers, List<String> keywords) {
    for (int i = 0; i < headers.length; i++) {
      final header = headers[i].toLowerCase().trim();
      for (final keyword in keywords) {
        if (header == keyword || header.contains(keyword)) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Obtenir la valeur d'une cellule de manière sûre
  String _getCell(List<String> row, int index, {String defaultValue = ''}) {
    if (index < 0 || index >= row.length) return defaultValue;
    return row[index].trim();
  }

  /// Convertir une cellule Excel en String
  String _cellToString(dynamic value) {
    if (value == null) return '';
    if (value is double) {
      // Si c'est un entier (ex: 3500.0 → "3500")
      return value == value.roundToDouble()
          ? value.round().toString()
          : value.toString();
    }
    return value.toString().trim();
  }

  /// Parser un double depuis une String
  double _parseDouble(String value) {
    if (value.isEmpty) return 0;
    // Remplacer virgule par point (format français)
    final cleaned = value.replaceAll(',', '.').replaceAll(' ', '');
    return double.tryParse(cleaned) ?? 0;
  }

  /// Parser un int depuis une String
  int _parseInt(String value) {
    if (value.isEmpty) return 0;
    final cleaned = value.replaceAll(' ', '').replaceAll('.', '');
    // Essayer d'abord int, puis double arrondi
    return int.tryParse(cleaned) ?? (double.tryParse(cleaned)?.round() ?? 0);
  }

  /// Détecter l'unité
  String _parseUnit(String value) {
    final v = value.toLowerCase().trim();
    if (v.contains('kg') || v.contains('kilo')) return 'kg';
    if (v.contains('litre') || v.contains('liter') || v == 'l') return 'litre';
    if (v.contains('boite') || v.contains('boîte') || v.contains('box')) {
      return 'boite';
    }
    return 'piece';
  }

  // =============================================
  //     EXTRAIRE L'ID DEPUIS L'URL GOOGLE SHEETS
  // =============================================

  String? _extractSheetId(String url) {
    final regex = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)');
    final match = regex.firstMatch(url);
    return match?.group(1);
  }

  /// Extraire le gid (ID de feuille spécifique)
  String _extractGid(String url) {
    final regex = RegExp(r'gid=([0-9]+)');
    final match = regex.firstMatch(url);
    return match?.group(1) ?? '0';
  }
}