import 'package:flutter/material.dart';
import '../models/cart_item_model.dart';
import '../models/product_model.dart';

class CartService extends ChangeNotifier {
  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List.unmodifiable(_items);
  int get itemCount => _items.length;
  int get totalQuantity =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount =>
      _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  String get formattedTotal => '${totalAmount.toStringAsFixed(0)} FC';

  // =============================================
  //           AJOUTER AU PANIER
  // =============================================

  void addProduct(ProductModel product) {
    final index = _items.indexWhere((item) => item.product.id == product.id);

    if (index != -1) {
      // Produit déjà dans le panier → augmenter la quantité
      if (_items[index].quantity < product.stock) {
        _items[index].quantity++;
      }
    } else {
      // Nouveau produit dans le panier
      _items.add(CartItemModel(product: product, quantity: 1));
    }
    notifyListeners();
  }

  // =============================================
  //           RETIRER DU PANIER
  // =============================================

  void removeProduct(String productId) {
    _items.removeWhere((item) => item.product.id == productId);
    notifyListeners();
  }

  // =============================================
  //          MODIFIER LA QUANTITÉ
  // =============================================

  void increaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      if (_items[index].quantity < _items[index].product.stock) {
        _items[index].quantity++;
        notifyListeners();
      }
    }
  }

  void decreaseQuantity(String productId) {
    final index = _items.indexWhere((item) => item.product.id == productId);
    if (index != -1) {
      if (_items[index].quantity > 1) {
        _items[index].quantity--;
      } else {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  // =============================================
  //            VIDER LE PANIER
  // =============================================

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  // =============================================
  //        VÉRIFIER SI DANS LE PANIER
  // =============================================

  bool isInCart(String productId) {
    return _items.any((item) => item.product.id == productId);
  }

  int getQuantity(String productId) {
    try {
      return _items.firstWhere((item) => item.product.id == productId).quantity;
    } catch (_) {
      return 0;
    }
  }
}