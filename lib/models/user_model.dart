class UserModel {
  String id;
  String fullName;
  String username;
  String password;
  String role;         // 'admin' ou 'caissier'
  String phone;
  bool isActive;
  DateTime createdAt;

  UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.password,
    this.role = 'caissier',
    this.phone = '',
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convertir en Map (pour stockage)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'username': username,
      'password': password,
      'role': role,
      'phone': phone,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Créer depuis un Map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      fullName: map['fullName'],
      username: map['username'],
      password: map['password'],
      role: map['role'] ?? 'caissier',
      phone: map['phone'] ?? '',
      isActive: map['isActive'] ?? true,
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
}