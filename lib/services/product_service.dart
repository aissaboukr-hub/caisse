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
  //            RECHERCHE / FILTRE
  // =============================================

  List<ProductModel> getProducts({String? category, String? search}) {
    var result = _products.where((p) => p.isAvailable).toList();

    if (category != null && category != 'Tous') {
      result = result.where((p) => p.category == category).toList();
    }

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q) ||
            (p.barcode != null && p.barcode!.contains(q)) ||
            p.id.contains(q);
      }).toList();
    }

    return result;
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