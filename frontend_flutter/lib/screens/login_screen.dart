import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onBack,
    required this.onSignupPressed,
    required this.onLogin,
    required this.onQuickAccess,
  });

  final VoidCallback onBack;
  final VoidCallback onSignupPressed;
  final Future<String?> Function(String username, String password) onLogin;
  final Future<String?> Function() onQuickAccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await widget.onLogin(
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  Future<void> _quickAccess() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final error = await widget.onQuickAccess();

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 980;

    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                  child: isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _authIntroPanel(
                                title: 'Connexion',
                                subtitle:
                                    'Accédez à votre espace de pilotage, à vos prédictions et à vos indicateurs opérationnels.',
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: _loginCard()),
                          ],
                        )
                      : SingleChildScrollView(
                          child: _loginCard(),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authIntroPanel({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF001A6E), Color(0xFF0A2EA6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33001A6E),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EcoSmart Auth',
            style: TextStyle(
              color: Color(0xFFDDE6FF),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFFDDE6FF),
              height: 1.45,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 18),
          const _InfoLine(
              icon: Icons.lock_outline, text: 'Session sécurisée JWT'),
          const _InfoLine(
              icon: Icons.memory_outlined, text: 'Connexion backend + ML'),
          const _InfoLine(
              icon: Icons.tune_outlined, text: 'Accès aux fonctions métier'),
        ],
      ),
    );
  }

  Widget _loginCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Text(
                      'Connexion sécurisée',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Connectez-vous pour accéder aux fonctionnalités métier de la plateforme.',
                style: TextStyle(
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _usernameCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nom d utilisateur'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nom d utilisateur requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Mot de passe'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Mot de passe requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.login),
                label: Text(_loading ? 'Connexion...' : 'Se connecter'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loading ? null : _quickAccess,
                icon: const Icon(Icons.flash_on_outlined),
                label: const Text('Accès démo rapide'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : widget.onSignupPressed,
                child: const Text('Pas de compte ? Créer un compte'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFDDE6FF), size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Color(0xFFDDE6FF)),
          ),
        ],
      ),
    );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF7F9FF), Color(0xFFEEF3FF), Color(0xFFF8FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -40,
            child: Container(
              width: 260,
              height: 260,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x11214BFF),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x0C000091),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
