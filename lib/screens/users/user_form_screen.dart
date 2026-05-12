import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/custom_textfield.dart';

class UserFormScreen extends StatefulWidget {
  final UserModel? user; // null = ajout, non-null = modification

  const UserFormScreen({super.key, this.user});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _userService = UserService();

  String _selectedRole = 'caissier';
  bool _isEditing = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.user != null;

    if (_isEditing) {
      _fullNameController.text = widget.user!.fullName;
      _usernameController.text = widget.user!.username;
      _passwordController.text = widget.user!.password;
      _phoneController.text = widget.user!.phone;
      _selectedRole = widget.user!.role;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _saveUser() {
    if (!_formKey.currentState!.validate()) return;

    final user = UserModel(
      id: _isEditing ? widget.user!.id : _userService.generateId(),
      fullName: _fullNameController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      role: _selectedRole,
      phone: _phoneController.text.trim(),
      isActive: _isEditing ? widget.user!.isActive : true,
      createdAt: _isEditing ? widget.user!.createdAt : DateTime.now(),
    );

    bool success;
    if (_isEditing) {
      success = _userService.updateUser(user);
    } else {
      success = _userService.addUser(user);
    }

    if (success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? '✅ Utilisateur modifié avec succès'
                : '✅ Utilisateur ajouté avec succès',
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('❌ Ce nom d\'utilisateur existe déjà'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        title: Text(
          _isEditing ? 'Modifier l\'utilisateur' : 'Nouvel utilisateur',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // ---- AVATAR ILLUSTRATION ----
              _buildHeader(),
              const SizedBox(height: 30),

              // ---- SECTION : Informations personnelles ----
              _buildSectionTitle('Informations personnelles', Icons.person),
              const SizedBox(height: 12),

              _buildFormField(
                controller: _fullNameController,
                label: 'Nom complet',
                icon: Icons.badge_outlined,
                validator: (v) =>
                    v!.isEmpty ? 'Le nom complet est requis' : null,
              ),

              _buildFormField(
                controller: _phoneController,
                label: 'Téléphone',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 25),

              // ---- SECTION : Identifiants de connexion ----
              _buildSectionTitle(
                  'Identifiants de connexion', Icons.vpn_key_outlined),
              const SizedBox(height: 12),

              _buildFormField(
                controller: _usernameController,
                label: 'Nom d\'utilisateur',
                icon: Icons.alternate_email_rounded,
                validator: (v) =>
                    v!.isEmpty ? 'Le nom d\'utilisateur est requis' : null,
              ),

              _buildFormField(
                controller: _passwordController,
                label: 'Mot de passe',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePassword,
                validator: (v) {
                  if (v!.isEmpty) return 'Le mot de passe est requis';
                  if (v.length < 4) return 'Minimum 4 caractères';
                  return null;
                },
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade500,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              const SizedBox(height: 25),

              // ---- SECTION : Rôle ----
              _buildSectionTitle('Rôle de l\'utilisateur', Icons.work_outline),
              const SizedBox(height: 12),
              _buildRoleSelector(),

              const SizedBox(height: 40),

              // ---- BOUTON SAUVEGARDER ----
              _buildSaveButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade50, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _isEditing ? Icons.edit_note_rounded : Icons.person_add_rounded,
              size: 32,
              color: Colors.indigo.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Modifier le profil' : 'Créer un compte',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditing
                      ? 'Mettez à jour les informations'
                      : 'Remplissez les informations du caissier',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo.shade600),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Colors.indigo.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        validator: validator,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          prefixIcon: Icon(icon, color: Colors.indigo.shade300, size: 22),
          suffixIcon: suffixIcon,
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.indigo.shade400, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.red.shade300),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.red.shade400, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Row(
      children: [
        // Caissier
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedRole = 'caissier'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _selectedRole == 'caissier'
                    ? Colors.teal.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedRole == 'caissier'
                      ? Colors.teal.shade400
                      : Colors.grey.shade200,
                  width: _selectedRole == 'caissier' ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 30,
                    color: _selectedRole == 'caissier'
                        ? Colors.teal.shade600
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Caissier',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _selectedRole == 'caissier'
                          ? Colors.teal.shade700
                          : Colors.grey.shade500,
                    ),
                  ),
                  if (_selectedRole == 'caissier')
                    Icon(Icons.check_circle, color: Colors.teal.shade400, size: 18),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Admin
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedRole = 'admin'),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: _selectedRole == 'admin'
                    ? Colors.indigo.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedRole == 'admin'
                      ? Colors.indigo.shade400
                      : Colors.grey.shade200,
                  width: _selectedRole == 'admin' ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 30,
                    color: _selectedRole == 'admin'
                        ? Colors.indigo.shade600
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Admin',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _selectedRole == 'admin'
                          ? Colors.indigo.shade700
                          : Colors.grey.shade500,
                    ),
                  ),
                  if (_selectedRole == 'admin')
                    Icon(Icons.check_circle,
                        color: Colors.indigo.shade400, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 5,
          shadowColor: Colors.indigo.withOpacity(0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_isEditing ? Icons.save_rounded : Icons.person_add_rounded,
                size: 22),
            const SizedBox(width: 10),
            Text(
              _isEditing ? 'ENREGISTRER LES MODIFICATIONS' : 'CRÉER LE COMPTE',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}