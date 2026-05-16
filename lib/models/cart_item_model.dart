import 'product_model.dart';

class CartItemModel {
  ProductModel product;
  int quantity;

  CartItemModel({
    required this.product,
    this.quantity = 1,
  });

  double get totalPrice => product.price * quantity;

  String get formattedTotal => '${totalPrice.toStringAsFixed(0)} DZ';
  String get formattedPrice => '${product.price.toStringAsFixed(0)} DZ';

  Map<String, dynamic> toMap() {
    return {
      'productName': product.name,
      'productPrice': product.price,
      'quantity': quantity,
      'total': totalPrice,
    };
  }

  factory CartItemModel.fromMap(Map<String, dynamic> map) {
    return CartItemModel(
      product: ProductModel(
        id: '',
        name: map['productName'] ?? 'Produit inconnu',
        price: (map['productPrice'] as num?)?.toDouble() ?? 0,
      ),
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
    );
  }
}