import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';

class ProductService extends ChangeNotifier {
  static final ProductService _instance = ProductService._internal();
  factory ProductService() => _instance;
  ProductService._internal() {
    _loadProducts();
  }

  static const String _storageKey = 'caisse_products';

  List<ProductModel> _products = [];
  bool _isLoaded = false;

  // =============================================
  //           CHARGEMENT / SAUVEGARDE
  // =============================================

  Future<void> _loadProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);

      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        _products = decoded.map((m) => ProductModel.fromMap(m)).toList();
      } else {
        // ⚠️ PLUS DE PRODUITS PAR DÉFAUT — Liste vide
        _products = [];
        await _saveProducts();
      }
    } catch (e) {
      debugPrint('Erreur chargement produits: $e');
      _products = [];
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String json = jsonEncode(
        _products.map((p) => p.toMap()).toList(),
      );
      await prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('Erreur sauvegarde produits: $e');
    }
  }

  // =============================================
  //               GETTERS
  // =============================================

  List<ProductModel> get products => List.unmodifiable(_products);
  bool get isLoaded => _isLoaded;
  bool get isEmpty => _products.isEmpty;

  List<String> get categories {
    final cats = _products.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['Tous', ...cats];
  }

    // =============================================
  //     RECHERCHE / FILTRE AVEC WILDCARD (%)
  // =============================================

  List<ProductModel> getProducts({String? category, String? search}) {
    var result = _products.where((p) => p.isAvailable).toList();

    // Filtrer par catégorie
    if (category != null && category != 'Tous') {
      result = result.where((p) => p.category == category).toList();
    }

    // Filtrer par recherche (avec support wildcard %)
    if (search != null && search.trim().isNotEmpty) {
      final query = search.trim();
      final hasWildcard = query.contains('%');

      if (hasWildcard) {
        // ═══════════════════════════════════════
        //   RECHERCHE AVEC WILDCARD %
        //   % = n'importe quels caractères
        // ═══════════════════════════════════════
        final pattern = _wildcardToRegex(query);
        final regex = RegExp(pattern, caseSensitive: false);

        result = result.where((p) {
          return regex.hasMatch(p.name) ||
              regex.hasMatch(p.category) ||
              (p.barcode != null && regex.hasMatch(p.barcode!)) ||
              regex.hasMatch(p.id);
        }).toList();
      } else {
        // ═══════════════════════════════════════
        //   RECHERCHE CLASSIQUE (contient)
        // ═══════════════════════════════════════
        final q = query.toLowerCase();
        result = result.where((p) {
          return p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q) ||
              (p.barcode != null &&
                  p.barcode!.toLowerCase().contains(q)) ||
              p.id.contains(q);
        }).toList();
      }
    }

    return result;
  }

  // =============================================
  //   CONVERTIR WILDCARD % EN EXPRESSION RÉGULIÈRE
  // =============================================

  String _wildcardToRegex(String wildcard) {
    // Échapper les caractères spéciaux regex sauf %
    // puis remplacer % par .*
    var pattern = '';

    for (int i = 0; i < wildcard.length; i++) {
      final char = wildcard[i];
      if (char == '%') {
        pattern += '.*';  // % = n'importe quels caractères
      } else if (char == '_') {
        pattern += '.';   // _ = un seul caractère (comme SQL)
      } else {
        // Échapper les caractères spéciaux regex
        pattern += RegExp.escape(char);
      }
    }

    return pattern;
  }

  // =============================================
  //        RECHERCHE PAR CODE-BARRES
  // =============================================

  ProductModel? findByBarcode(String barcode) {
    try {
      return _products.firstWhere(
        (p) =>
            p.barcode != null &&
            p.barcode!.trim() == barcode.trim() &&
            p.isAvailable,
      );
    } catch (_) {
      return null;
    }
  }

  // =============================================
  //              CRUD SIMPLE
  // =============================================

  bool addProduct(ProductModel product) {
    if (_products.any(
        (p) => p.name.toLowerCase() == product.name.toLowerCase())) {
      return false;
    }
    _products.add(product);
    _saveProducts();
    notifyListeners();
    return true;
  }

  bool updateProduct(ProductModel product) {
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index == -1) return false;
    _products[index] = product;
    _saveProducts();
    notifyListeners();
    return true;
  }

  bool deleteProduct(String id) {
    final index = _products.indexWhere((p) => p.id == id);
    if (index == -1) return false;
    _products.removeAt(index);
    _saveProducts();
    notifyListeners();
    return true;
  }

  void decreaseStock(String productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index].stock -= quantity;
      if (_products[index].stock < 0) {
        _products[index].stock = 0;
      }
      _saveProducts();
      notifyListeners();
    }
  }

  // =============================================
  //        IMPORT EN MASSE (NOUVEAU)
  // =============================================

  /// Importer une liste de produits
  /// [replaceAll] = true → remplace tout, false → ajoute
  /// Retourne le nombre de produits ajoutés
  Future<int> importProducts(
    List<ProductModel> newProducts, {
    bool replaceAll = false,
  }) async {
    if (replaceAll) {
      _products.clear();
    }

    int added = 0;
    int skipped = 0;

    for (final product in newProducts) {
      // Ignorer les lignes vides / sans nom
      if (product.name.trim().isEmpty) continue;

      // Vérifier si le produit existe déjà (par nom)
      final exists = _products.any(
        (p) => p.name.toLowerCase().trim() == product.name.toLowerCase().trim(),
      );

      if (exists) {
        skipped++;
        continue;
      }

      // Attribuer un ID si manquant
      if (product.id.isEmpty) {
        product.id = generateId();
      }

      _products.add(product);
      added++;
    }

    await _saveProducts();
    notifyListeners();

    debugPrint(
        'Import terminé: $added ajoutés, $skipped ignorés (doublons)');
    return added;
  }

  /// Supprimer tous les produits
  Future<void> clearAllProducts() async {
    _products.clear();
    await _saveProducts();
    notifyListeners();
  }

  /// Générer un ID unique
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}