import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sale_model.dart';
import '../models/cart_item_model.dart';

class SaleService extends ChangeNotifier {
  static final SaleService _instance = SaleService._internal();
  factory SaleService() => _instance;
  SaleService._internal() {
    _loadSales();
  }

  static const String _storageKey = 'caisse_sales';

  List<SaleModel> _sales = [];
  bool _isLoaded = false;

  Future<void> _loadSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? data = prefs.getString(_storageKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        _sales = decoded.map((m) => SaleModel.fromMap(m)).toList();
      }
    } catch (e) {
      debugPrint('Erreur chargement ventes: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveSales() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String json =
          jsonEncode(_sales.map((s) => s.toMap()).toList());
      await prefs.setString(_storageKey, json);
    } catch (e) {
      debugPrint('Erreur sauvegarde ventes: $e');
    }
  }

  // =============================================
  //           ENREGISTRER UNE VENTE
  // =============================================

  Future<SaleModel> recordSale({
    required String cashierName,
    required List<CartItemModel> items,
    required double amountPaid,
    String paymentMethod = 'cash',
  }) async {
    final total = items.fold(0.0, (sum, item) => sum + item.totalPrice);
    final change = amountPaid - total;

    final sale = SaleModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      cashierName: cashierName,
      items: List.from(items),
      totalAmount: total,
      amountPaid: amountPaid,
      change: change,
      paymentMethod: paymentMethod,
      saleDate: DateTime.now(),
    );

    _sales.insert(0, sale);
    await _saveSales();
    notifyListeners();
    return sale;
  }

  // =============================================
  //               GETTERS
  // =============================================

  List<SaleModel> get sales => List.unmodifiable(_sales);
  bool get isLoaded => _isLoaded;
  int get totalSales => _sales.length;

  // =============================================
  //          FILTRES PAR DATE
  // =============================================

  List<SaleModel> getSalesByDate(DateTime date) {
    return _sales.where((s) =>
        s.saleDate.year == date.year &&
        s.saleDate.month == date.month &&
        s.saleDate.day == date.day).toList();
  }

  List<SaleModel> getSalesByDateRange(DateTime start, DateTime end) {
    return _sales.where((s) =>
        s.saleDate.isAfter(start.subtract(const Duration(days: 1))) &&
        s.saleDate.isBefore(end.add(const Duration(days: 1)))).toList();
  }

  // =============================================
  //           STATISTIQUES
  // =============================================

  double get todayRevenue {
    final now = DateTime.now();
    return getSalesByDate(now)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
  }

  int get todaySalesCount {
    final now = DateTime.now();
    return getSalesByDate(now).length;
  }

  int get todayItemsSold {
    final now = DateTime.now();
    return getSalesByDate(now)
        .fold(0, (sum, s) => sum + s.totalItems);
  }

  double get totalRevenue =>
      _sales.fold(0.0, (sum, s) => sum + s.totalAmount);

  Map<String, double> get revenueByCashier {
    final map = <String, double>{};
    for (final sale in _sales) {
      map[sale.cashierName] =
          (map[sale.cashierName] ?? 0) + sale.totalAmount;
    }
    return map;
  }

  // =============================================
  //          SUPPRIMER UNE VENTE
  // =============================================

  bool deleteSale(String id) {
    final index = _sales.indexWhere((s) => s.id == id);
    if (index == -1) return false;
    _sales.removeAt(index);
    _saveSales();
    notifyListeners();
    return true;
  }

  /// Supprimer tout l'historique
  Future<void> clearAllSales() async {
    _sales.clear();
    await _saveSales();
    notifyListeners();
  }
}