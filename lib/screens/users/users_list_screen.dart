import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/user_card.dart';
import 'user_form_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final UserService _userService = UserService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterRole = 'all'; // 'all', 'admin', 'caissier'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserModel> get _filteredUsers {
    var users = _userService.searchUsers(_searchQuery);
    if (_filterRole != 'all') {
      users = users.where((u) => u.role == _filterRole).toList();
    }
    return users;
  }

  // ---- NAVIGUER VERS LE FORMULAIRE ----
  void _openForm({UserModel? user}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserFormScreen(user: user),
      ),
    );
    if (result == true) setState(() {});
  }

  // ---- CONFIRMER LA SUPPRESSION ----
  void _confirmDelete(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400),
            const SizedBox(width: 10),
            const Text('Supprimer'),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment supprimer "${user.fullName}" ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            onPressed: () {
              _userService.deleteUser(user.id);
              Navigator.pop(ctx);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🗑️ ${user.fullName} supprimé'),
                  backgroundColor: Colors.red.shade500,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  margin: const EdgeInsets.all(16),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _filteredUsers;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      // ---- APP BAR ----
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'Gestion des Utilisateurs',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 19),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded),
            tooltip: 'Ajouter un utilisateur',
            onPressed: () => _openForm(),
          ),
        ],
      ),

      // ---- CORPS ----
      body: Column(
        children: [
          // ---- HEADER STATISTIQUES ----
          _buildStatsHeader(),

          // ---- BARRE DE RECHERCHE ----
          _buildSearchBar(),

          // ---- FILTRES ----
          _buildFilterChips(),

          const SizedBox(height: 8),

          // ---- LISTE ----
          Expanded(
            child: filteredUsers.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      return UserCard(
                        user: user,
                        onEdit: () => _openForm(user: user),
                        onDelete: () => _confirmDelete(user),
                        onToggleStatus: () {
                          _userService.toggleUserStatus(user.id);
                          setState(() {});
                        },
                      );
                    },
                  ),
          ),
        ],
      ),

      // ---- FAB ----
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Ajouter',
            style: TextStyle(fontWeight: FontWeight.w600)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // ---- WIDGET STATISTIQUES ----
  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
        ),
      ),
      child: Row(
        children: [
          _buildStatItem(
            'Total',
            _userService.totalUsers.toString(),
            Icons.people_outline,
          ),
          _buildStatItem(
            'Actifs',
            _userService.activeUsers.toString(),
            Icons.check_circle_outline,
          ),
          _buildStatItem(
            'Admins',
            _userService.adminCount.toString(),
            Icons.shield_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- BARRE DE RECHERCHE ----
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Rechercher un utilisateur...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(Icons.search, color: Colors.indigo.shade300),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: Colors.grey.shade400),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ---- FILTRES PAR RÔLE ----
  Widget _buildFilterChips() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _buildFilterChip('all', 'Tous', Icons.people),
          const SizedBox(width: 8),
          _buildFilterChip('admin', 'Admins', Icons.shield),
          const SizedBox(width: 8),
          _buildFilterChip('caissier', 'Caissiers', Icons.shopping_cart),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _filterRole == value;
    return GestureDetector(
      onTap: () => setState(() => _filterRole = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigo.shade600 : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isSelected ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- ÉTAT VIDE ----
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Aucun utilisateur trouvé',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez une autre recherche ou ajoutez un utilisateur',
            style: TextStyle(color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}