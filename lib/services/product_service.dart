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
        _products = _getDefaultProducts();
        await _saveProducts();
      }
    } catch (e) {
      debugPrint('Erreur chargement produits: $e');
      _products = _getDefaultProducts();
    }

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String json = jsonEncode(_products.map((p) => p.toMap()).toList());
      await prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('Erreur sauvegarde produits: $e');
    }
  }

  // =============================================
  //          PRODUITS PAR DÉFAUT
  // =============================================

  List<ProductModel> _getDefaultProducts() {
    return [
      // 🥤 Boissons
      ProductModel(
        id: '1', name: 'Coca-Cola 1L', category: 'Boissons',
        price: 3500, stock: 50, unit: 'piece',
      ),
      ProductModel(
        id: '2', name: 'Fanta Orange 1L', category: 'Boissons',
        price: 3500, stock: 40, unit: 'piece',
      ),
      ProductModel(
        id: '3', name: 'Eau Pure 1.5L', category: 'Boissons',
        price: 1500, stock: 100, unit: 'piece',
      ),
      ProductModel(
        id: '4', name: 'Jus de Fruit 50cl', category: 'Boissons',
        price: 2500, stock: 30, unit: 'piece',
      ),
      ProductModel(
        id: '5', name: 'Bière Primus', category: 'Boissons',
        price: 4000, stock: 60, unit: 'piece',
      ),

      // 🍞 Alimentation
      ProductModel(
        id: '6', name: 'Pain Complet', category: 'Alimentation',
        price: 2000, stock: 25, unit: 'piece',
      ),
      ProductModel(
        id: '7', name: 'Riz 5Kg', category: 'Alimentation',
        price: 12000, stock: 20, unit: 'piece',
      ),
      ProductModel(
        id: '8', name: 'Huile Végétale 2L', category: 'Alimentation',
        price: 8500, stock: 15, unit: 'piece',
      ),
      ProductModel(
        id: '9', name: 'Farine de Maïs 1Kg', category: 'Alimentation',
        price: 3000, stock: 35, unit: 'piece',
      ),
      ProductModel(
        id: '10', name: 'Sucre 1Kg', category: 'Alimentation',
        price: 2500, stock: 40, unit: 'piece',
      ),

      // 🧴 Hygiène
      ProductModel(
        id: '11', name: 'Savon Dove', category: 'Hygiène',
        price: 4500, stock: 20, unit: 'piece',
      ),
      ProductModel(
        id: '12', name: 'Dentifrice Signal', category: 'Hygiène',
        price: 3000, stock: 18, unit: 'piece',
      ),
      ProductModel(
        id: '13', name: 'Shampooing 400ml', category: 'Hygiène',
        price: 5500, stock: 12, unit: 'piece',
      ),
      ProductModel(
        id: '14', name: 'Papier Toilette x4', category: 'Hygiène',
        price: 6000, stock: 22, unit: 'piece',
      ),

      // 🍬 Confiserie
      ProductModel(
        id: '15', name: 'Chocolat Dairy Milk', category: 'Confiserie',
        price: 3000, stock: 30, unit: 'piece',
      ),
      ProductModel(
        id: '16', name: 'Biscuit LU Petit', category: 'Confiserie',
        price: 2000, stock: 45, unit: 'piece',
      ),
    ];
  }

  // =============================================
  //               GETTERS
  // =============================================

  List<ProductModel> get products => List.unmodifiable(_products);
  bool get isLoaded => _isLoaded;

  List<String> get categories {
    final cats = _products.map((p) => p.category).toSet().toList();
    cats.sort();
    return ['Tous', ...cats];
  }

  // =============================================
  //              RECHERCHE / FILTRE
  // =============================================

  List<ProductModel> getProducts({String? category, String? search}) {
    var result = _products.where((p) => p.isAvailable).toList();

    if (category != null && category != 'Tous') {
      result = result.where((p) => p.category == category).toList();
    }

    if (search != null && search.isNotEmpty) {
      final q = search.toLowerCase();
      result = result.where((p) => p.name.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  // =============================================
  //              CRUD
  // =============================================

  bool addProduct(ProductModel product) {
    if (_products.any((p) => p.name.toLowerCase() == product.name.toLowerCase())) {
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

  /// Diminuer le stock après une vente
  void decreaseStock(String productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index].stock -= quantity;
      if (_products[index].stock < 0) _products[index].stock = 0;
      _saveProducts();
      notifyListeners();
    }
  }

  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}