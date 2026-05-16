import 'cart_item_model.dart';

class SaleModel {
  String id;
  String cashierName;
  List<CartItemModel> items;
  double totalAmount;
  double amountPaid;
  double change;
  String paymentMethod;
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
      'items': items
          .map((item) => {
                'productName': item.product.name,
                'productPrice': item.product.price,
                'quantity': item.quantity,
                'total': item.totalPrice,
              })
          .toList(),
      'totalAmount': totalAmount,
      'amountPaid': amountPaid,
      'change': change,
      'paymentMethod': paymentMethod,
      'saleDate': saleDate.toIso8601String(),
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    final List<CartItemModel> parsedItems = [];

    if (map['items'] != null) {
      for (final itemMap in (map['items'] as List)) {
        parsedItems.add(
          CartItemModel.fromMap(itemMap as Map<String, dynamic>),
        );
      }
    }

    return SaleModel(
      id: map['id'] ?? '',
      cashierName: map['cashierName'] ?? 'Inconnu',
      items: parsedItems,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      amountPaid: (map['amountPaid'] as num?)?.toDouble() ?? 0,
      change: (map['change'] as num?)?.toDouble() ?? 0,
      paymentMethod: map['paymentMethod'] ?? 'cash',
      saleDate: map['saleDate'] != null
          ? DateTime.parse(map['saleDate'])
          : DateTime.now(),
    );
  }

  String get formattedDate {
    return '${saleDate.day.toString().padLeft(2, '0')}/'
        '${saleDate.month.toString().padLeft(2, '0')}/'
        '${saleDate.year}';
  }

  String get formattedTime {
    return '${saleDate.hour.toString().padLeft(2, '0')}:'
        '${saleDate.minute.toString().padLeft(2, '0')}';
  }

  String get formattedDateTime => '$formattedDate $formattedTime';
}