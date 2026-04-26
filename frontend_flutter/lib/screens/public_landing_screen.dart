import 'package:flutter/material.dart';

import '../services/api_service.dart';

enum _PublicLang { fr, ar }

class PublicLandingScreen extends StatefulWidget {
  const PublicLandingScreen({
    super.key,
    required this.api,
    required this.onLoginPressed,
    required this.onSignupPressed,
    required this.onQuickAccess,
  });

  final ApiService api;
  final VoidCallback onLoginPressed;
  final VoidCallback onSignupPressed;
  final Future<String?> Function() onQuickAccess;

  @override
  State<PublicLandingScreen> createState() => _PublicLandingScreenState();
}

class _PublicLandingScreenState extends State<PublicLandingScreen> {
  bool _loading = false;
  bool _publicDataLoading = false;
  String? _error;
  String? _publicDataError;
  _PublicLang _lang = _PublicLang.fr;

  List<_CollectionPoint> _points = const [
    _CollectionPoint('Tunis Centre', 'Tunis', 36.8065, 10.1815),
    _CollectionPoint('Lac 1', 'Tunis', 36.8453, 10.2729),
    _CollectionPoint('Sfax Ville', 'Sfax', 34.7406, 10.7603),
    _CollectionPoint('Sousse Medina', 'Sousse', 35.8256, 10.6084),
    _CollectionPoint('Bizerte Port', 'Bizerte', 37.2746, 9.8739),
    _CollectionPoint('Gabes Nord', 'Gabes', 33.8815, 10.0982),
  ];

  List<_GovData> _governorates = const [
    _GovData('Tunis', 1280, 74),
    _GovData('Sfax', 1090, 69),
    _GovData('Sousse', 980, 66),
    _GovData('Nabeul', 860, 63),
    _GovData('Bizerte', 720, 58),
    _GovData('Gabes', 640, 55),
  ];

  @override
  void initState() {
    super.initState();
    _loadPublicData();
  }

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

  Future<void> _loadPublicData() async {
    setState(() {
      _publicDataLoading = true;
      _publicDataError = null;
    });

    try {
      final payload = await widget.api.publicTunisiaDashboard();
      final rawPoints = (payload['collection_points'] as List<dynamic>? ?? []);
      final rawGov = (payload['governorate_stats'] as List<dynamic>? ?? []);

      final points = rawPoints
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => _CollectionPoint(
              (item['site'] ?? '').toString(),
              (item['governorate'] ?? '').toString(),
              (item['lat'] as num?)?.toDouble() ?? 0,
              (item['lng'] as num?)?.toDouble() ?? 0,
            ),
          )
          .where((p) => p.site.isNotEmpty && p.governorate.isNotEmpty)
          .toList();

      final gov = rawGov
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => _GovData(
              (item['name'] ?? '').toString(),
              (item['monthly_tons'] as num?)?.toInt() ?? 0,
              (item['recovery_rate'] as num?)?.toInt() ?? 0,
            ),
          )
          .where((g) => g.name.isNotEmpty)
          .toList();

      if (!mounted) return;
      setState(() {
        if (points.isNotEmpty) {
          _points = points;
        }
        if (gov.isNotEmpty) {
          _governorates = gov;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publicDataError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _publicDataLoading = false;
      });
    }
  }

  String _t(String fr, String ar) => _lang == _PublicLang.fr ? fr : ar;

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
                        const SizedBox(height: 20),
                        if (isDesktop)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _collectionMapPanel()),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 4,
                                child: _governorateDashboardPanel(),
                              ),
                            ],
                          )
                        else ...[
                          _collectionMapPanel(),
                          const SizedBox(height: 12),
                          _governorateDashboardPanel(),
                        ],
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
            'TN',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('RÉPUBLIQUE TUNISIENNE', 'الجمهورية التونسية'),
                style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _t(
                  'EcoSmart · Plateforme déchets intelligente',
                  'EcoSmart · منصة ذكية لإدارة النفايات',
                ),
                style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
        _langSwitcher(),
      ],
    );
  }

  Widget _langSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDCE2F6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _langPill(_PublicLang.fr, 'FR'),
          _langPill(_PublicLang.ar, 'AR'),
        ],
      ),
    );
  }

  Widget _langPill(_PublicLang target, String label) {
    final selected = target == _lang;
    return InkWell(
      onTap: () => setState(() => _lang = target),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? const Color(0xFF001A6E) : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
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
          Text(
            _t('EcoSmart Public', 'EcoSmart العامة'),
            style: const TextStyle(
              color: Color(0xFFDDE6FF),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t(
              'Traçabilité moderne pour une filière déchets performante',
              'تتبع حديث لسلسلة نفايات أكثر كفاءة',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 38,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _t(
              'Page publique: découvrez les objectifs du projet, ses indicateurs clés et la démarche MLOps. Les opérations métiers restent accessibles uniquement après connexion.',
              'صفحة عامة: اكتشف أهداف المشروع ومؤشراته الرئيسية ونهج MLOps. الوظائف التشغيلية متاحة فقط بعد تسجيل الدخول.',
            ),
            style: const TextStyle(
              color: Color(0xFFDDE6FF),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          _InfoLine(
            icon: Icons.language_outlined,
            text: _t('Présentation publique du projet', 'عرض عام للمشروع'),
          ),
          _InfoLine(
            icon: Icons.lock_outline,
            text: _t(
              'Fonctions sensibles réservées aux sessions actives',
              'الوظائف الحساسة مخصصة للجلسات النشطة',
            ),
          ),
          _InfoLine(
            icon: Icons.auto_graph_outlined,
            text: _t(
              'Pipeline IA et suivi de performance',
              'مسار ذكاء اصطناعي ومتابعة الأداء',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(label: _t('API sécurisée', 'واجهة مؤمنة')),
              _HeroChip(label: _t('Prédiction IA', 'تنبؤ بالذكاء الاصطناعي')),
              _HeroChip(label: _t('Tableau de bord privé', 'لوحة تحكم خاصة')),
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
            Text(
              _t('Accéder à la plateforme', 'الدخول إلى المنصة'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _t(
                'Choisissez votre parcours: connexion sécurisée, création de compte, ou accès démo.',
                'اختر مسارك: تسجيل دخول آمن أو إنشاء حساب أو تجربة سريعة.',
              ),
              style: const TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.onLoginPressed,
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(_t('Connexion', 'تسجيل الدخول')),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onSignupPressed,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(_t('Inscription', 'إنشاء حساب')),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _loading ? null : _handleQuickAccess,
              icon: const Icon(Icons.flash_on_outlined),
              label: Text(
                _loading
                    ? _t('Connexion...', 'جاري الدخول...')
                    : _t('Accès démo', 'دخول تجريبي'),
              ),
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
      _InfoCard(
        title: _t('Objectif Projet', 'هدف المشروع'),
        body: _t(
          'Classifier les déchets et estimer la valeur de revente via un pipeline ML supervisé.',
          'تصنيف النفايات وتقدير قيمة إعادة البيع عبر مسار تعلم آلي موجه.',
        ),
        icon: Icons.track_changes_outlined,
      ),
      _InfoCard(
        title: _t('Périmètre Public', 'النطاق العام'),
        body: _t(
          'Présentation de la mission, de la méthode et des bénéfices. Sans accès aux données sensibles.',
          'عرض المهمة والمنهجية والفوائد دون الوصول إلى البيانات الحساسة.',
        ),
        icon: Icons.public_outlined,
      ),
      _InfoCard(
        title: _t('Fonctions Privées', 'الوظائف الخاصة'),
        body: _t(
          'Prédictions, historique, métriques détaillées et actions métier disponibles après authentification.',
          'التنبؤات والسجل والمؤشرات التفصيلية متاحة بعد المصادقة.',
        ),
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

  Widget _collectionMapPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Carte des points de collecte', 'خريطة نقاط التجميع'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _t(
                'Vue publique des points actifs en Tunisie (données démonstration).',
                'عرض عام لنقاط التجميع النشطة في تونس (بيانات تجريبية).',
              ),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_publicDataLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (_publicDataLoading) const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _publicDataLoading ? null : _loadPublicData,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(_t('Actualiser', 'تحديث')),
                ),
              ],
            ),
            if (_publicDataError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _publicDataError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [Color(0xFFEFF4FF), Color(0xFFDDE8FF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Opacity(
                      opacity: 0.15,
                      child: Icon(
                        Icons.map,
                        size: 160,
                        color: const Color(0xFF001A6E).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  ..._mapMarkers(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _points
                  .map(
                    (p) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFF),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFDCE2F6)),
                      ),
                      child: Text(
                        '${p.site} · ${p.governorate}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _mapMarkers() {
    final lats = _points.map((e) => e.lat).toList();
    final lngs = _points.map((e) => e.lng).toList();
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    return _points.map((point) {
      final x = ((point.lng - minLng) / (maxLng - minLng + 0.0001)) * 84 + 8;
      final y = ((maxLat - point.lat) / (maxLat - minLat + 0.0001)) * 74 + 12;

      return Positioned(
        left: x,
        top: y,
        child: Tooltip(
          message: '${point.site} (${point.governorate})',
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF001A6E),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55001A6E),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _governorateDashboardPanel() {
    final maxVolume =
        _governorates.map((e) => e.monthlyTons).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _t('Dashboard public par gouvernorat', 'لوحة عامة حسب الولاية'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _t(
                'Volumes mensuels collectés et taux de valorisation par région.',
                'حجم التجميع الشهري ونسبة التثمين حسب كل ولاية.',
              ),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            ..._governorates.map((g) {
              final ratio = g.monthlyTons / maxVolume;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            g.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          '${g.monthlyTons} t/mois · ${g.recoveryRate}%',
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 9,
                        backgroundColor: const Color(0xFFE5EAF8),
                        valueColor:
                            const AlwaysStoppedAnimation(Color(0xFF0A2EA6)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CollectionPoint {
  const _CollectionPoint(this.site, this.governorate, this.lat, this.lng);

  final String site;
  final String governorate;
  final double lat;
  final double lng;
}

class _GovData {
  const _GovData(this.name, this.monthlyTons, this.recoveryRate);

  final String name;
  final int monthlyTons;
  final int recoveryRate;
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
