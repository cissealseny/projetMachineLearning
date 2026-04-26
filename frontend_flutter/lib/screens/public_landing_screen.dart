import 'package:flutter/material.dart';

class PublicLandingScreen extends StatefulWidget {
  const PublicLandingScreen({
    super.key,
    required this.onLoginPressed,
    required this.onSignupPressed,
    required this.onQuickAccess,
  });

  final VoidCallback onLoginPressed;
  final VoidCallback onSignupPressed;
  final Future<String?> Function() onQuickAccess;

  @override
  State<PublicLandingScreen> createState() => _PublicLandingScreenState();
}

class _PublicLandingScreenState extends State<PublicLandingScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _handleQuickAccess() async {
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
          const _LandingBackground(),
          SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _header(),
                        const SizedBox(height: 24),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _heroPanel()),
                              const SizedBox(width: 24),
                              Expanded(flex: 4, child: _actionPanel()),
                            ],
                          )
                        else ...[
                          _heroPanel(),
                          const SizedBox(height: 16),
                          _actionPanel(),
                        ],
                        const SizedBox(height: 20),
                        _publicInfoGrid(isDesktop: isDesktop),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFF001A6E), Color(0xFF000091)],
            ),
          ),
          alignment: Alignment.center,
          child: const Text(
            'FR',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RÉPUBLIQUE FRANÇAISE',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'EcoSmart · Plateforme déchets intelligente',
                style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroPanel() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          colors: [Color(0xFF001A6E), Color(0xFF0A2EA6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3A001A6E),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EcoSmart Public',
            style: TextStyle(
              color: Color(0xFFDDE6FF),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Traçabilité moderne pour une filière déchets performante',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 38,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Page publique: découvrez les objectifs du projet, ses indicateurs clés et la démarche MLOps. Les opérations métiers restent accessibles uniquement après connexion.',
            style: TextStyle(
              color: Color(0xFFDDE6FF),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const _InfoLine(
            icon: Icons.language_outlined,
            text: 'Présentation publique du projet',
          ),
          const _InfoLine(
            icon: Icons.lock_outline,
            text: 'Fonctions sensibles réservées aux sessions actives',
          ),
          const _InfoLine(
            icon: Icons.auto_graph_outlined,
            text: 'Pipeline IA et suivi de performance',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const [
              _HeroChip(label: 'API sécurisée'),
              _HeroChip(label: 'Prédiction IA'),
              _HeroChip(label: 'Tableau de bord privé'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Accéder à la plateforme',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choisissez votre parcours: connexion sécurisée, création de compte, ou accès démo.',
              style: TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onLoginPressed,
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Connexion'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onSignupPressed,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('Inscription'),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _loading ? null : _handleQuickAccess,
              icon: const Icon(Icons.flash_on_outlined),
              label: Text(_loading ? 'Connexion...' : 'Accès démo'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _publicInfoGrid({required bool isDesktop}) {
    final cards = [
      const _InfoCard(
        title: 'Objectif Projet',
        body:
            'Classifier les déchets et estimer la valeur de revente via un pipeline ML supervisé.',
        icon: Icons.track_changes_outlined,
      ),
      const _InfoCard(
        title: 'Périmètre Public',
        body:
            'Présentation de la mission, de la méthode et des bénéfices. Sans accès aux données sensibles.',
        icon: Icons.public_outlined,
      ),
      const _InfoCard(
        title: 'Fonctions Privées',
        body:
            'Prédictions, historique, métriques détaillées et actions métier disponibles après authentification.',
        icon: Icons.admin_panel_settings_outlined,
      ),
    ];

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i < cards.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _LandingBackground extends StatelessWidget {
  const _LandingBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F8FF), Color(0xFFEEF2FF), Color(0xFFF7FAFF)],
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
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x19214BFF),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x14000091),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: const Color(0x33214BFF),
        border: Border.all(color: const Color(0x55FFFFFF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
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
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFDDE6FF)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE8EDFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF001A6E)),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(color: Color(0xFF475569), height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
