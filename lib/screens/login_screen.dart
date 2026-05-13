import 'package:flutter/material.dart';
import '../widgets/custom_textfield.dart';
import '../services/user_service.dart';
import 'users/users_list_screen.dart';
import 'sales/sales_screen.dart'; // ← NOUVEL IMPORT ÉTAPE 3

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UserService _userService = UserService();

  bool _isLoading = false;
  bool _rememberMe = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // =============================================
  //          LOGIQUE DE CONNEXION
  // =============================================
  void _handleLogin() {
    String username = _emailController.text.trim();
    String password = _passwordController.text.trim();

    // Validation des champs vides
    if (username.isEmpty || password.isEmpty) {
      _showSnackBar('Veuillez remplir tous les champs', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    // Simulation d'une requête serveur (délai 2 sec)
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // Authentification via UserService
      final user = _userService.authenticate(username, password);

      if (user != null) {
        _showSnackBar('✅ Bienvenue ${user.fullName} !', isError: false);

        // Redirection selon le rôle après un court délai
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!mounted) return;
          
          if (user.role == 'admin') {
            // Admin → Gestion des utilisateurs
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const UsersListScreen(),
              ),
            );
          } else {
            // Caissier → Interface de Caisse / Vente (Étape 3)
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => SalesScreen(cashierName: user.fullName),
              ),
            );
          }
        });
      } else {
        _showSnackBar(
          '❌ Identifiants incorrects ou compte désactivé',
          isError: true,
        );
      }
    });
  }

  // =============================================
  //          SNACKBAR (messages)
  // =============================================
  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 15),
        ),
        backgroundColor:
            isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =============================================
  //               BUILD PRINCIPAL
  // =============================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ---- DÉGRADÉ DE FOND ----
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A237E), // Indigo foncé
              Color(0xFF3949AB), // Indigo moyen
              Color(0xFF5C6BC0), // Indigo clair
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ---- LOGO ----
                    _buildLogo(),
                    const SizedBox(height: 15),

                    // ---- TITRE ----
                    const Text(
                      'MA CAISSE',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Gestion de point de vente',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 50),

                    // ---- CARTE DE CONNEXION ----
                    _buildLoginCard(),
                    const SizedBox(height: 25),

                    // ---- PIED DE PAGE ----
                    Text(
                      'v1.0.0 • © 2025 Ma Caisse',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =============================================
  //              WIDGET LOGO
  // =============================================
  Widget _buildLogo() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        Icons.point_of_sale_rounded,
        size: 55,
        color: Colors.indigo.shade700,
      ),
    );
  }

  // =============================================
  //           CARTE DE CONNEXION
  // =============================================
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // ---- Titre du formulaire ----
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, color: Colors.indigo.shade600),
              const SizedBox(width: 8),
              Text(
                'Identification',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.indigo.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),

          // ---- Champ Utilisateur ----
          CustomTextField(
            controller: _emailController,
            label: 'Nom d\'utilisateur',
            icon: Icons.person_outline_rounded,
            keyboardType: TextInputType.text,
          ),

          // ---- Champ Mot de passe ----
          CustomTextField(
            controller: _passwordController,
            label: 'Mot de passe',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
          ),

          const SizedBox(height: 8),

          // ---- Se souvenir + Mot de passe oublié ----
          Row(
            children: [
              Checkbox(
                value: _rememberMe,
                activeColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (value) {
                  setState(() => _rememberMe = value ?? false);
                },
              ),
              Text(
                'Se souvenir de moi',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO : Mot de passe oublié
                },
                child: Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(
                    color: Colors.indigo.shade400,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ---- Bouton Connexion ----
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 5,
                shadowColor: Colors.indigo.withOpacity(0.4),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 22),
                        SizedBox(width: 10),
                        Text(
                          'SE CONNECTER',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}