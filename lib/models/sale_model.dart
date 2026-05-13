import 'cart_item_model.dart';

class SaleModel {
  String id;
  String cashierName;
  List<CartItemModel> items;
  double totalAmount;
  double amountPaid;
  double change;
  String paymentMethod; // 'cash', 'card', 'mobile'
  DateTime saleDate;

  SaleModel({
    required this.id,
    required this.cashierName,
    required this.items,
    required this.totalAmount,
    required this.amountPaid,
    required this.change,
    this.paymentMethod = 'cash',
    DateTime? saleDate,
  }) : saleDate = saleDate ?? DateTime.now();

  int get totalItems => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cashierName': cashierName,
      'items': items.map((item) => {
        'productName': item.product.name,
        'productPrice': item.product.price,
        'quantity': item.quantity,
        'total': item.totalPrice,
      }).toList(),
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'change': change,
      'paymentMethod': paymentMethod,
      'saleDate': saleDate.toIso8601String(),
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    return SaleModel(
      id: map['id'],
      cashierName: map['cashierName'] ?? 'Inconnu',
      items: [], // Simplifié pour le stockage
      totalAmount: (map['totalAmount'] as num).toDouble(),
      amountPaid: (map['amountPaid'] as num).toDouble(),
      change: (map['change'] as num).toDouble(),
      paymentMethod: map['paymentMethod'] ?? 'cash',
      saleDate: DateTime.parse(map['saleDate']),
    );
  }
}