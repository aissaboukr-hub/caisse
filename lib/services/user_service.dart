import 'package:flutter/material.dart';
import '../models/user_model.dart';

class UserService extends ChangeNotifier {
  // Singleton
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  // Liste des utilisateurs (en mémoire — on ajoutera SQLite plus tard)
  final List<UserModel> _users = [
    UserModel(
      id: '1',
      fullName: 'Administrateur',
      username: 'admin',
      password: '1234',
      role: 'admin',
      phone: '+243 000 000 000',
      isActive: true,
      createdAt: DateTime(2025, 1, 1),
    ),
    UserModel(
      id: '2',
      fullName: 'Jean Kabila',
      username: 'jean',
      password: '5678',
      role: 'caissier',
      phone: '+243 999 888 777',
      isActive: true,
      createdAt: DateTime(2025, 3, 15),
    ),
    UserModel(
      id: '3',
      fullName: 'Marie Lukaku',
      username: 'marie',
      password: '0000',
      role: 'caissier',
      phone: '+243 111 222 333',
      isActive: false,
      createdAt: DateTime(2025, 4, 10),
    ),
  ];

  // Lire tous les utilisateurs
  List<UserModel> get users => List.unmodifiable(_users);

  // Nombre total
  int get totalUsers => _users.length;
  int get activeUsers => _users.where((u) => u.isActive).length;
  int get adminCount => _users.where((u) => u.role == 'admin').length;

  // Rechercher des utilisateurs
  List<UserModel> searchUsers(String query) {
    if (query.isEmpty) return users;
    final q = query.toLowerCase();
    return _users.where((user) {
      return user.fullName.toLowerCase().contains(q) ||
          user.username.toLowerCase().contains(q) ||
          user.role.toLowerCase().contains(q) ||
          user.phone.toLowerCase().contains(q);
    }).toList();
  }

  // Ajouter un utilisateur
  bool addUser(UserModel user) {
    // Vérifier si le username existe déjà
    if (_users.any((u) => u.username.toLowerCase() == user.username.toLowerCase())) {
      return false;
    }
    _users.add(user);
    notifyListeners();
    return true;
  }

  // Modifier un utilisateur
  bool updateUser(UserModel updatedUser) {
    final index = _users.indexWhere((u) => u.id == updatedUser.id);
    if (index == -1) return false;

    // Vérifier l'unicité du username (sauf pour l'utilisateur actuel)
    final duplicate = _users.any((u) =>
        u.id != updatedUser.id &&
        u.username.toLowerCase() == updatedUser.username.toLowerCase());
    if (duplicate) return false;

    _users[index] = updatedUser;
    notifyListeners();
    return true;
  }

    // Supprimer un utilisateur
  bool deleteUser(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) return false;
    _users.removeAt(index);
    notifyListeners();
    return true;
  }

  // Activer/Désactiver
  void toggleUserStatus(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index].isActive = !_users[index].isActive;
      notifyListeners();
    }
  }

  // Générer un ID unique
  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Authentification
  UserModel? authenticate(String username, String password) {
    try {
      return _users.firstWhere(
        (u) => u.username == username && 
               u.password == password && 
               u.isActive,
      );
    } catch (_) {
      return null;
    }
  }
}