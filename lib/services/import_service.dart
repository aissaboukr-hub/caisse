import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/product_model.dart';

class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  // =============================================
  //        IMPORT DEPUIS UN FICHIER EXCEL
  // =============================================

  Future<List<ProductModel>> importFromExcel(String filePath) async {
    try {
      final bytes = File(filePath).readAsBytesSync();
      final excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        throw Exception('Le fichier Excel ne contient aucune feuille');
      }

      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName];

      if (sheet == null || sheet.rows.isEmpty) {
        throw Exception('La feuille "$sheetName" est vide');
      }

      final List<List<String>> rows = [];
      for (final row in sheet.rows) {
        final List<String> stringRow = [];
        for (final cell in row) {
          stringRow.add(_cellToString(cell?.value));
        }
        rows.add(stringRow);
      }

      return _parseRows(rows);
    } catch (e) {
      debugPrint('Erreur import Excel: $e');
      rethrow;
    }
  }

  // =============================================
  //     IMPORT DEPUIS GOOGLE SHEETS (CSV)
  //     ⚠️ CORRIGÉ avec 3 méthodes de fallback
  // =============================================

  Future<List<ProductModel>> importFromGoogleSheets(String url) async {
    try {
      // 1. Extraire l'ID de la feuille Google Sheets
      final sheetId = _extractSheetId(url);
      if (sheetId == null || sheetId.isEmpty) {
        throw Exception(
          'URL Google Sheets invalide.\n\n'
          'Formats acceptés :\n'
          '• https://docs.google.com/spreadsheets/d/SHEET_ID/edit\n'
          '• https://docs.google.com/spreadsheets/d/SHEET_ID/edit#gid=0\n'
          '• https://docs.google.com/spreadsheets/d/SHEET_ID/edit?usp=sharing',
        );
      }

      // 2. Extraire le gid (ID de feuille spécifique)
      final gid = _extractGid(url);
      debugPrint('Sheet ID: $sheetId, GID: $gid');

      // 3. Essayer plusieurs méthodes de téléchargement
      String? csvContent;

      // ---- MÉTHODE 1 : /export?format=csv ----
      csvContent = await _tryDownload(
        'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$gid',
        'export',
      );

      // ---- MÉTHODE 2 : /pub?output=csv (feuille publiée) ----
      if (csvContent == null) {
        csvContent = await _tryDownload(
          'https://docs.google.com/spreadsheets/d/$sheetId/pub?output=csv&gid=$gid',
          'pub',
        );
      }

      // ---- MÉTHODE 3 : /gviz/tq (API interne Google) ----
      if (csvContent == null) {
        csvContent = await _tryDownload(
          'https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:csv&gid=$gid',
          'gviz',
        );
      }

      // ---- MÉTHODE 4 : Sans le gid ----
      if (csvContent == null) {
        csvContent = await _tryDownload(
          'https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv',
          'export-sans-gid',
        );
      }

      if (csvContent == null) {
        throw Exception(
          'Impossible d\'accéder au Google Sheet.\n\n'
          'Vérifiez que :\n'
          '1. Le lien est correct\n'
          '2. Le Sheet est partagé avec "Tous les détenteurs du lien"\n'
          '3. Le Sheet n\'est pas protégé par mot de passe\n\n'
          'Astuce : Dans Google Sheets → Fichier → Partager → '
          '→ "Tous les détenteurs du lien"',
        );
      }

      // 4. Décoder le CSV
      final List<List<dynamic>> csvRows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
      ).convert(csvContent);

      // 5. Convertir en List<List<String>>
      final List<List<String>> rows = csvRows
          .map((row) =>
              row.map((cell) => _cleanCell(cell.toString())).toList())
          .toList();

      // 6. Parser les produits
      return _parseRows(rows);
    } catch (e) {
      debugPrint('Erreur import Google Sheets: $e');
      rethrow;
    }
  }

  // =============================================
  //     ESSAYER UNE URL DE TÉLÉCHARGEMENT
  // =============================================

  Future<String?> _tryDownload(String downloadUrl, String method) async {
    try {
      debugPrint('[$method] Tentative: $downloadUrl');

      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: {
          'Accept': 'text/csv, text/plain, */*',
          'User-Agent': 'Mozilla/5.0 (Flutter App)',
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Délai d\'attente dépassé'),
      );

      debugPrint('[$method] Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = utf8.decode(response.bodyBytes);

        // Vérifier que c'est bien du CSV (pas une page HTML d'erreur)
        if (body.contains('<!DOCTYPE html>') ||
            body.contains('<html') ||
            body.contains('ServiceLogin')) {
          debugPrint('[$method] Reçu HTML au lieu de CSV → ignoré');
          return null;
        }

        // Vérifier qu'il y a du contenu
        if (body.trim().isEmpty) {
          debugPrint('[$method] Contenu vide → ignoré');
          return null;
        }

        debugPrint('[$method] ✅ Succès ! ${body.length} caractères');
        return body;
      }

      debugPrint('[$method] ❌ Échec (${response.statusCode})');
      return null;
    } catch (e) {
      debugPrint('[$method] ❌ Exception: $e');
      return null;
    }
  }

  // =============================================
  //        PARSER LES LIGNES EN PRODUITS
  // =============================================

  List<ProductModel> _parseRows(List<List<String>> rows) {
    if (rows.isEmpty) return [];

    // Nettoyer les lignes vides
    rows.removeWhere(
        (row) => row.isEmpty || row.every((cell) => cell.trim().isEmpty));

    if (rows.isEmpty) return [];

    // 1. Détecter les colonnes depuis l'en-tête
    final headers =
        rows.first.map((h) => h.toLowerCase().trim()).toList();

    final nameIdx = _findColumn(headers, [
      'nom', 'name', 'produit', 'product', 'designation',
      'désignation', 'designation', 'libellé', 'libelle',
      'article', 'intitulé', 'intitule',
    ]);

    final priceIdx = _findColumn(headers, [
      'prix', 'price', 'tarif', 'pu', 'montant',
      'prix unitaire', 'prix_unitaire', 'p.u',
    ]);

    final stockIdx = _findColumn(headers, [
      'stock', 'quantité', 'quantite', 'qty', 'qte',
      'qté', 'qtt', 'disponible',
    ]);

    final barcodeIdx = _findColumn(headers, [
      'code-barres', 'code_barres', 'barcode', 'code barres',
      'ean', 'code-barre', 'code_barre', 'codes', 'code',
    ]);

    debugPrint(
      'Colonnes détectées: nom=$nameIdx, '
      'prix=$priceIdx, stock=$stockIdx, barcode=$barcodeIdx',
    );

    final effectiveNameIdx = nameIdx >= 0 ? nameIdx : 0;

    // 2. Parcourir les données (ignorer l'en-tête)
    final List<ProductModel> products = [];
    int idCounter = DateTime.now().millisecondsSinceEpoch;

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];

      if (row.isEmpty || row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }

      final name = _getCell(row, effectiveNameIdx);
      if (name.isEmpty) continue;

      final price = _parseDouble(_getCell(row, priceIdx));
      final stock = _parseInt(_getCell(row, stockIdx, defaultValue: '0'));
      final barcode = _getCell(row, barcodeIdx, defaultValue: '');

      products.add(ProductModel(
        id: '${idCounter++}',
        name: name,
        category: 'Divers',
        price: price,
        stock: stock,
        unit: 'piece',
        barcode: barcode.isNotEmpty ? barcode : null,
        isAvailable: true,
        createdAt: DateTime.now(),
      ));
    }

    return products;
  }

  // =============================================
  //           UTILITAIRES
  // =============================================

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

  String _getCell(List<String> row, int index,
      {String defaultValue = ''}) {
    if (index < 0 || index >= row.length) return defaultValue;
    return row[index].trim();
  }

  String _cellToString(dynamic value) {
    if (value == null) return '';
    if (value is double) {
      return value == value.roundToDouble()
          ? value.round().toString()
          : value.toString();
    }
    return value.toString().trim();
  }

  /// Nettoyer une cellule CSV (BOM, guillemets, espaces)
  String _cleanCell(String value) {
    var v = value.trim();
    // Supprimer BOM UTF-8
    if (v.startsWith('\uFEFF')) {
      v = v.substring(1);
    }
    // Supprimer guillemets CSV
    if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
      v = v.substring(1, v.length - 1);
    }
    return v.trim();
  }

  double _parseDouble(String value) {
    if (value.isEmpty) return 0;
    final cleaned = value
        .replaceAll(',', '.')
        .replaceAll(' ', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
    return double.tryParse(cleaned) ?? 0;
  }

  int _parseInt(String value) {
    if (value.isEmpty) return 0;
    final cleaned = value
        .replaceAll(' ', '')
        .replaceAll('.', '')
        .replaceAll('"', '')
        .replaceAll("'", '');
    return int.tryParse(cleaned) ??
        (double.tryParse(cleaned)?.round() ?? 0);
  }

  // =============================================
  //     EXTRAIRE L'ID DEPUIS L'URL GOOGLE SHEETS
  //     ⚠️ CORRIGÉ pour supporter tous les formats
  // =============================================

  String? _extractSheetId(String url) {
    // Nettoyer l'URL
    var cleanUrl = url.trim();

    // Format 1: https://docs.google.com/spreadsheets/d/SHEET_ID/...
    final regex1 = RegExp(r'/spreadsheets/d/([a-zA-Z0-9_-]+)');
    final match1 = regex1.firstMatch(cleanUrl);
    if (match1 != null) {
      return match1.group(1);
    }

    // Format 2: https://docs.google.com/spreadsheets/d/SHEET_ID
    final regex2 =
        RegExp(r'spreadsheets/d/([a-zA-Z0-9_-]{20,})');
    final match2 = regex2.firstMatch(cleanUrl);
    if (match2 != null) {
      return match2.group(1);
    }

    // Format 3: Si l'utilisateur a collé juste l'ID
    final regex3 = RegExp(r'^[a-zA-Z0-9_-]{30,}$');
    if (regex3.hasMatch(cleanUrl)) {
      return cleanUrl;
    }

    return null;
  }

  /// Extraire le gid (ID de feuille spécifique)
  String _extractGid(String url) {
    // gid= dans l'URL
    final regex = RegExp(r'gid=([0-9]+)');
    final match = regex.firstMatch(url);
    if (match != null) {
      return match.group(1) ?? '0';
    }

    // #gid= dans le fragment
    final regex2 = RegExp(r'#gid=([0-9]+)');
    final match2 = regex2.firstMatch(url);
    if (match2 != null) {
      return match2.group(1) ?? '0';
    }

    return '0';
  }
}