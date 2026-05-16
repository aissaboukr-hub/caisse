import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserService extends ChangeNotifier {
  // Singleton
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal() {
    _loadUsers(); // Charger les données au démarrage
  }

  // Clé de stockage
  static const String _storageKey = 'caisse_users';

  // Liste des utilisateurs en mémoire
  List<UserModel> _users = [];
  bool _isLoaded = false;

  // =============================================
  //           CHARGEMENT DES DONNÉES
  // =============================================

  /// Charger les utilisateurs depuis SharedPreferences
  Future<void> _loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? usersJson = prefs.getString(_storageKey);

      if (usersJson != null && usersJson.isNotEmpty) {
        // Décoder le JSON en liste de Map
        final List<dynamic> decoded = jsonDecode(usersJson);
        _users = decoded.map((map) => UserModel.fromMap(map)).toList();
      } else {
        // Première ouverture → créer les utilisateurs par défaut
        _users = _getDefaultUsers();
        await _saveUsers();
      }
    } catch (e) {
      debugPrint('Erreur chargement utilisateurs: $e');
      _users = _getDefaultUsers();
    }

    _isLoaded = true;
    notifyListeners();
  }

  /// Sauvegarder les utilisateurs dans SharedPreferences
  Future<void> _saveUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Convertir la liste en JSON
      final List<Map<String, dynamic>> usersMapList =
          _users.map((user) => user.toMap()).toList();
      final String usersJson = jsonEncode(usersMapList);
      await prefs.setString(_storageKey, usersJson);
    } catch (e) {
      debugPrint('Erreur sauvegarde utilisateurs: $e');
    }
  }

  /// Utilisateurs par défaut (première installation)
  List<UserModel> _getDefaultUsers() {
    return [
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
        fullName: 'Adel Kabila',
        username: 'adel',
        password: '12345',
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
  }

  // =============================================
  //            GETTERS ( Lecture )
  // =============================================

  List<UserModel> get users => List.unmodifiable(_users);
  bool get isLoaded => _isLoaded;
  int get totalUsers => _users.length;
  int get activeUsers => _users.where((u) => u.isActive).length;
  int get adminCount => _users.where((u) => u.role == 'admin').length;

  // =============================================
  //             RECHERCHE
  // =============================================

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

  // =============================================
  //             AJOUTER
  // =============================================

  bool addUser(UserModel user) {
    // Vérifier si le username existe déjà
    if (_users.any(
        (u) => u.username.toLowerCase() == user.username.toLowerCase())) {
      return false;
    }
    _users.add(user);
    _saveUsers(); // ← SAUVEGARDE AUTOMATIQUE
    notifyListeners();
    return true;
  }

  // =============================================
  //             MODIFIER
  // =============================================

  bool updateUser(UserModel updatedUser) {
    final index = _users.indexWhere((u) => u.id == updatedUser.id);
    if (index == -1) return false;

    // Vérifier l'unicité du username (sauf pour l'utilisateur actuel)
    final duplicate = _users.any((u) =>
        u.id != updatedUser.id &&
        u.username.toLowerCase() == updatedUser.username.toLowerCase());
    if (duplicate) return false;

    _users[index] = updatedUser;
    _saveUsers(); // ← SAUVEGARDE AUTOMATIQUE
    notifyListeners();
    return true;
  }

  // =============================================
  //             SUPPRIMER
  // =============================================

  bool deleteUser(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index == -1) return false;
    _users.removeAt(index);
    _saveUsers(); // ← SAUVEGARDE AUTOMATIQUE
    notifyListeners();
    return true;
  }

  // =============================================
  //          ACTIVER / DÉSACTIVER
  // =============================================

  void toggleUserStatus(String id) {
    final index = _users.indexWhere((u) => u.id == id);
    if (index != -1) {
      _users[index].isActive = !_users[index].isActive;
      _saveUsers(); // ← SAUVEGARDE AUTOMATIQUE
      notifyListeners();
    }
  }

  // =============================================
  //          AUTHENTIFICATION
  // =============================================

  UserModel? authenticate(String username, String password) {
    try {
      return _users.firstWhere(
        (u) =>
            u.username == username &&
            u.password == password &&
            u.isActive,
      );
    } catch (_) {
      return null;
    }
  }

  // =============================================
  //        RÉINITIALISER ( pour debug )
  // =============================================

  Future<void> resetToDefaults() async {
    _users = _getDefaultUsers();
    await _saveUsers();
    notifyListeners();
  }

  // =============================================
  //          GÉNÉRER UN ID UNIQUE
  // =============================================

  String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}