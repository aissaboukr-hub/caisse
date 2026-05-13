class ProductModel {
  String id;
  String name;
  String category;     // Garde une valeur par défaut "Divers"
  double price;
  int stock;
  String unit;         // Garde une valeur par défaut "piece"
  String? imageUrl;
  String? barcode;
  bool isAvailable;
  DateTime createdAt;

  ProductModel({
    required this.id,
    required this.name,
    this.category = 'Divers',
    required this.price,
    this.stock = 0,
    this.unit = 'piece',
    this.imageUrl,
    this.barcode,
    this.isAvailable = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'unit': unit,
      'imageUrl': imageUrl,
      'barcode': barcode,
      'isAvailable': isAvailable,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'],
      name: map['name'],
      category: map['category'] ?? 'Divers',
      price: (map['price'] as num).toDouble(),
      stock: map['stock'] ?? 0,
      unit: map['unit'] ?? 'piece',
      imageUrl: map['imageUrl'],
      barcode: map['barcode'],
      isAvailable: map['isAvailable'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  String get unitLabel => '/ Pce';
}