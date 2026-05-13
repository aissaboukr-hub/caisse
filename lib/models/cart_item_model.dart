import 'product_model.dart';

class CartItemModel {
  ProductModel product;
  int quantity;

  CartItemModel({
    required this.product,
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;

  String get formattedTotal => '${totalPrice.toStringAsFixed(0)} FC';
  String get formattedPrice => '${product.price.toStringAsFixed(0)} FC';
}