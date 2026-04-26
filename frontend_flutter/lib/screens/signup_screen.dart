import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({
    super.key,
    required this.onBack,
    required this.onLoginPressed,
    required this.onSignup,
  });

  final VoidCallback onBack;
  final VoidCallback onLoginPressed;
  final Future<String?> Function(
    String fullName,
    String email,
    String username,
    String password,
  ) onSignup;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final message = await widget.onSignup(
      _fullNameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _usernameCtrl.text.trim(),
      _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (message == null) {
        _info = 'Compte créé avec succès. Vous pouvez vous connecter.';
      } else {
        _error = message;
      }
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
                                title: 'Inscription',
                                subtitle:
                                    'Créez votre accès pour préparer un espace utilisateur complet et évolutif.',
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(flex: 4, child: _signupCard()),
                          ],
                        )
                      : SingleChildScrollView(
                          child: _signupCard(),
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
            icon: Icons.person_add_alt_1,
            text: 'Parcours d inscription pro',
          ),
          const _InfoLine(
            icon: Icons.verified_user_outlined,
            text: 'Compte prêt pour accès privé',
          ),
          const _InfoLine(
            icon: Icons.settings_suggest_outlined,
            text: 'Intégration backend prévue',
          ),
        ],
      ),
    );
  }

  Widget _signupCard() {
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
                      'Créer un compte',
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
                'Cette page est prête pour un flux d inscription professionnel. L activation backend peut être branchée ensuite.',
                style: TextStyle(
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _fullNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nom complet requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email requis';
                  }
                  if (!value.contains('@')) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom d utilisateur',
                ),
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Minimum 3 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Minimum 8 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmer mot de passe',
                ),
                validator: (value) {
                  if (value != _passwordCtrl.text) {
                    return 'Les mots de passe ne correspondent pas';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loading ? null : _submit,
                icon: const Icon(Icons.how_to_reg_outlined),
                label: Text(
                  _loading ? 'Création...' : 'Créer mon compte',
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : widget.onLoginPressed,
                child: const Text('Déjà inscrit ? Aller à la connexion'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_info != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _info!,
                    style: const TextStyle(color: Color(0xFF14532D)),
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
