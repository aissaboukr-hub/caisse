import 'package:flutter/material.dart';
import '../models/user_model.dart';

class UserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const UserCard({
    super.key,
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: user.isActive
              ? Colors.green.withOpacity(0.2)
              : Colors.red.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // ---- AVATAR ----
            _buildAvatar(),
            const SizedBox(width: 14),

            // ---- INFORMATIONS ----
            Expanded(child: _buildUserInfo()),

            // ---- ACTIONS ----
            _buildActionMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: user.role == 'admin'
              ? [Colors.indigo.shade400, Colors.indigo.shade700]
              : [Colors.teal.shade300, Colors.teal.shade600],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (user.role == 'admin' ? Colors.indigo : Colors.teal)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nom complet
        Text(
          user.fullName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2D3436),
          ),
        ),
        const SizedBox(height: 4),

        // Username + rôle
        Row(
          children: [
            Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
            const SizedBox(width: 4),
            Text(
              '@${user.username}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 10),
            _buildRoleChip(),
          ],
        ),
        const SizedBox(height: 4),

        // Téléphone
        if (user.phone.isNotEmpty)
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                user.phone,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildRoleChip() {
    final isAdmin = user.role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin
            ? Colors.indigo.withOpacity(0.1)
            : Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAdmin ? '👑 Admin' : '🛒 Caissier',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isAdmin ? Colors.indigo : Colors.teal,
        ),
      ),
    );
  }

  Widget _buildActionMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            onEdit();
            break;
          case 'status':
            onToggleStatus();
            break;
          case 'delete':
            onDelete();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
              SizedBox(width: 10),
              Text('Modifier'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'status',
          child: Row(
            children: [
              Icon(
                user.isActive ? Icons.block : Icons.check_circle_outline,
                size: 20,
                color: user.isActive ? Colors.orange : Colors.green,
              ),
              const SizedBox(width: 10),
              Text(user.isActive ? 'Désactiver' : 'Activer'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 10),
              Text('Supprimer', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}