import 'dart:async';
import 'package:flutter/material.dart';

import '../models/predict_models.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    this.onLogout,
  });

  final ApiService api;
  final VoidCallback? onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _primaryBlue = Color(0xFF000091);
  static const _deepBlue = Color(0xFF001A6E);

  final _formKey = GlobalKey<FormState>();
  late final ApiService _api;

  // Sliders values
  double _poids = 25;
  double _volume = 50;
  double _conductivite = 3.5;
  double _opacite = 0.7;
  double _rigidite = 4.2;
  double _prix = 12;

  // Text controllers pour saisie manuelle
  late TextEditingController _poidsTextCtrl;
  late TextEditingController _volumeTextCtrl;
  late TextEditingController _conductiviteTextCtrl;
  late TextEditingController _opaciteTextCtrl;
  late TextEditingController _rigiditeTextCtrl;
  late TextEditingController _prixTextCtrl;

  final _sourceCtrl = TextEditingController(text: 'Usine_A');
  final _rapportCtrl = TextEditingController(
    text: 'Lot de plastique recupere a l usine A.',
  );

  bool _loading = false;
  bool _dashboardLoading = false;
  bool _authenticated = false;

  String? _error;
  String? _dashboardError;
  String? _publicHealthStatus;

  Map<String, dynamic>? _dashboard;
  PredictResponse? _result;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _api = widget.api;
    _authenticated = _api.isAuthenticated;

    _poidsTextCtrl = TextEditingController(text: _poids.toStringAsFixed(1));
    _volumeTextCtrl = TextEditingController(text: _volume.toStringAsFixed(1));
    _conductiviteTextCtrl = TextEditingController(text: _conductivite.toStringAsFixed(1));
    _opaciteTextCtrl = TextEditingController(text: _opacite.toStringAsFixed(1));
    _rigiditeTextCtrl = TextEditingController(text: _rigidite.toStringAsFixed(1));
    _prixTextCtrl = TextEditingController(text: _prix.toStringAsFixed(1));

    _loadPublicHealth();
    if (_authenticated) {
      _loadDashboard();
      _submitAuto();
    }
  }

  @override
  void dispose() {
    _poidsTextCtrl.dispose();
    _volumeTextCtrl.dispose();
    _conductiviteTextCtrl.dispose();
    _opaciteTextCtrl.dispose();
    _rigiditeTextCtrl.dispose();
    _prixTextCtrl.dispose();
    _sourceCtrl.dispose();
    _rapportCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSliderChanged(double value, Function(double) setter, TextEditingController ctrl) {
    setState(() => setter(value));
    ctrl.text = value.toStringAsFixed(1);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _submitAuto);
  }

  void _onTextChanged(String text, double min, double max, Function(double) setter) {
    final parsed = double.tryParse(text);
    if (parsed != null && parsed >= min && parsed <= max) {
      setState(() => setter(parsed));
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), _submitAuto);
    }
  }

  Future<void> _loadPublicHealth() async {
    try {
      final health = await _api.health();
      if (!mounted) return;
      setState(() => _publicHealthStatus = (health['status'] ?? '').toString());
    } catch (_) {
      if (!mounted) return;
      setState(() => _publicHealthStatus = 'indisponible');
    }
  }

  Future<void> _loadDashboard() async {
    if (!_authenticated) return;
    setState(() {
      _dashboardLoading = true;
      _dashboardError = null;
    });
    try {
      final data = await _api.dashboard();
      if (!mounted) return;
      setState(() => _dashboard = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dashboardError = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _dashboardLoading = false);
    }
  }

  Future<void> _submitAuto() async {
    if (!_authenticated) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = PredictRequest(
        poids: _poids,
        volume: _volume,
        conductivite: _conductivite,
        opacite: _opacite,
        rigidite: _rigidite,
        prixRevente: _prix,
        source: _sourceCtrl.text.trim(),
        rapportCollecte: _rapportCtrl.text.trim(),
      );
      final response = await _api.predict(request);
      if (!mounted) return;
      setState(() => _result = response);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _logout() {
    _api.logout();
    widget.onLogout?.call();
    setState(() {
      _authenticated = false;
      _dashboard = null;
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_dashboard?['summary'] as Map<String, dynamic>?) ?? {};
    final ml = (_dashboard?['ml'] as Map<String, dynamic>?) ?? {};
    final metrics = (ml['metrics'] as Map<String, dynamic>?) ?? {};
    final recent = (_dashboard?['recent_predictions'] as List<dynamic>?) ?? [];
    final isDesktop = MediaQuery.of(context).size.width >= 1080;

    if (!_authenticated) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              margin: const EdgeInsets.all(18),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Espace sécurisé',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text(
                      'Ce dashboard nécessite une session active.',
                      style: TextStyle(color: Color(0xFF475569), height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour à l accueil public'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          const _DashboardBackground(),
          SafeArea(
            child: Form(
              key: _formKey,
              child: isDesktop
                  ? Row(children: [
                      _sideRail(),
                      Expanded(child: _mainContent(summary, ml, metrics, recent)),
                    ])
                  : _mainContent(summary, ml, metrics, recent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainContent(
    Map<String, dynamic> summary,
    Map<String, dynamic> ml,
    Map<String, dynamic> metrics,
    List<dynamic> recent,
  ) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(summary),
                const SizedBox(height: 14),
                _kpiGrid(summary, ml, metrics),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 940;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: _predictionPanel()),
                        const SizedBox(width: 14),
                        Expanded(flex: 4, child: _systemPanel(ml, metrics)),
                      ],
                    );
                  }
                  return Column(children: [
                    _predictionPanel(),
                    const SizedBox(height: 14),
                    _systemPanel(ml, metrics),
                  ]);
                }),
                const SizedBox(height: 14),
                _historyPanel(recent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _predictionPanel() {
    Color categoryColor = const Color(0xFF000091);
    if (_result != null) {
      switch (_result!.categorie.toLowerCase()) {
        case 'plastique':
          categoryColor = Colors.blue;
          break;
        case 'métal':
        case 'metal':
          categoryColor = Colors.grey.shade700;
          break;
        case 'verre':
          categoryColor = Colors.teal;
          break;
        case 'papier':
          categoryColor = Colors.orange;
          break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Centre de prédiction',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Bougez les curseurs ou saisissez une valeur — la catégorie se met à jour en temps réel.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),

            // Résultat temps réel
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_result != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: categoryColor.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.category_outlined, color: categoryColor, size: 20),
                        const SizedBox(width: 8),
                        Text('Catégorie prédite',
                            style: TextStyle(color: categoryColor, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _result!.categorie,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._result!.probabilites.entries.map((entry) {
                      final pct = (entry.value * 100).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('$pct%'),
                              ],
                            ),
                            const SizedBox(height: 2),
                            LinearProgressIndicator(
                              value: entry.value,
                              backgroundColor: const Color(0xFFE2E8F0),
                              color: categoryColor,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Sliders avec saisie manuelle
            _sliderField('Poids (kg)', _poids, 0, 200, _poidsTextCtrl,
                (v) => _onSliderChanged(v, (x) => _poids = x, _poidsTextCtrl),
                (v) => _onTextChanged(v, 0, 200, (x) => _poids = x)),
            _sliderField('Volume (L)', _volume, 0, 200, _volumeTextCtrl,
                (v) => _onSliderChanged(v, (x) => _volume = x, _volumeTextCtrl),
                (v) => _onTextChanged(v, 0, 200, (x) => _volume = x)),
            _sliderField('Conductivité', _conductivite, 0, 10, _conductiviteTextCtrl,
                (v) => _onSliderChanged(v, (x) => _conductivite = x, _conductiviteTextCtrl),
                (v) => _onTextChanged(v, 0, 10, (x) => _conductivite = x)),
            _sliderField('Opacité', _opacite, 0, 1, _opaciteTextCtrl,
                (v) => _onSliderChanged(v, (x) => _opacite = x, _opaciteTextCtrl),
                (v) => _onTextChanged(v, 0, 1, (x) => _opacite = x)),
            _sliderField('Rigidité', _rigidite, 0, 10, _rigiditeTextCtrl,
                (v) => _onSliderChanged(v, (x) => _rigidite = x, _rigiditeTextCtrl),
                (v) => _onTextChanged(v, 0, 10, (x) => _rigidite = x)),
            _sliderField('Prix revente', _prix, 0, 100, _prixTextCtrl,
                (v) => _onSliderChanged(v, (x) => _prix = x, _prixTextCtrl),
                (v) => _onTextChanged(v, 0, 100, (x) => _prix = x)),

            const SizedBox(height: 10),
            _textField(_sourceCtrl, 'Source'),
            const SizedBox(height: 10),
            _textField(_rapportCtrl, 'Rapport collecte', maxLines: 2),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sliderField(
    String label,
    double value,
    double min,
    double max,
    TextEditingController ctrl,
    ValueChanged<double> onSliderChanged,
    ValueChanged<String> onTextChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(
                width: 90,
                height: 36,
                child: TextFormField(
                  controller: ctrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF000091)),
                    ),
                  ),
                  onChanged: onTextChanged,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF000091),
              thumbColor: const Color(0xFF000091),
              inactiveTrackColor: const Color(0xFFDCE2F6),
              overlayColor: const Color(0x29000091),
              trackHeight: 4,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onSliderChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 800), _submitAuto);
      },
    );
  }

  Widget _sideRail() {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(colors: [_deepBlue, _primaryBlue]),
                    ),
                    alignment: Alignment.center,
                    child: const Text('FR',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('EcoSmart\nOps Center',
                        style: TextStyle(fontWeight: FontWeight.w800, height: 1.2)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const _NavItem(icon: Icons.dashboard_outlined, label: 'Vue générale'),
              const _NavItem(icon: Icons.tune_outlined, label: 'Prédiction'),
              const _NavItem(icon: Icons.history_outlined, label: 'Historique'),
              const _NavItem(icon: Icons.memory_outlined, label: 'Santé ML'),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: const Color(0xFFF4F6FF),
                ),
                child: Text(
                  'API: ${_publicHealthStatus ?? 'chargement...'}',
                  style: const TextStyle(color: Color(0xFF1E3A8A), fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnexion'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Map<String, dynamic> summary) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF001A6E), Color(0xFF0A2EA6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x29001A6E), blurRadius: 20, offset: Offset(0, 10))
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cockpit opérationnel',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        height: 1.1)),
                SizedBox(height: 8),
                Text(
                  'Prédiction en temps réel — bougez les curseurs ou saisissez les valeurs.',
                  style: TextStyle(color: Color(0xFFDCE7FF), height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: _dashboardLoading ? null : _loadDashboard,
                icon: const Icon(Icons.sync),
                label: const Text('Actualiser'),
              ),
              const SizedBox(height: 8),
              _badge('Dernière activité: ${summary['last_prediction_at'] ?? '-'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid(
    Map<String, dynamic> summary,
    Map<String, dynamic> ml,
    Map<String, dynamic> metrics,
  ) {
    final cards = [
      _kpiCard(label: 'Prédictions', value: '${summary['predictions_count'] ?? 0}', delta: 'Total cumulé', icon: Icons.insights_outlined),
      _kpiCard(label: 'Taux de succès', value: '${summary['success_rate'] ?? 0}%', delta: 'Requêtes 2xx', icon: Icons.verified_outlined),
      _kpiCard(label: 'État modèle', value: ml['model_ready'] == true ? 'Prêt' : 'Indisponible', delta: 'Pipeline ML', icon: Icons.model_training_outlined),
      _kpiCard(label: 'Accuracy', value: _shortMetric(metrics['accuracy']), delta: 'Métrique globale', icon: Icons.speed_outlined),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final perRow = constraints.maxWidth > 1100 ? 4 : constraints.maxWidth > 720 ? 2 : 1;
      final width = (constraints.maxWidth - (12 * (perRow - 1))) / perRow;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((card) => SizedBox(width: width, child: card)).toList(),
      );
    });
  }

  Widget _kpiCard({required String label, required String value, required String delta, required IconData icon}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: const Color(0xFFE8EDFF), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: _deepBlue),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(delta, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _systemPanel(Map<String, dynamic> ml, Map<String, dynamic> metrics) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Supervision système', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('État API, disponibilité modèle et signaux.', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            _statusRow(title: 'API Backend', value: _publicHealthStatus ?? 'chargement...', ok: (_publicHealthStatus ?? '').toLowerCase() == 'ok'),
            _statusRow(title: 'Modèle ML', value: ml['model_ready'] == true ? 'prêt' : 'indisponible', ok: ml['model_ready'] == true),
            _statusRow(title: 'Accuracy', value: _shortMetric(metrics['accuracy']), ok: true),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDCE2F6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Métriques modèle', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Precision: ${_shortMetric(metrics['precision'])}'),
                  Text('Recall: ${_shortMetric(metrics['recall'])}'),
                  Text('F1: ${_shortMetric(metrics['f1'])}'),
                ],
              ),
            ),
            if (_dashboardLoading) ...[const SizedBox(height: 12), const LinearProgressIndicator()],
            if (_dashboardError != null) ...[const SizedBox(height: 10), Text(_dashboardError!, style: const TextStyle(color: Colors.red))],
          ],
        ),
      ),
    );
  }

  Widget _historyPanel(List<dynamic> recent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Flux des dernières prédictions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Timeline des opérations exécutées par la session.', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              const Text('Aucune opération récente.')
            else
              ...recent.take(12).map((item) {
                final map = item as Map<String, dynamic>;
                final response = map['response_payload'] as Map<String, dynamic>?;
                final ok = (map['ml_status_code'] ?? 500) < 300;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFDCE2F6)),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: ok ? const Color(0xFFE8FAEE) : const Color(0xFFFFECEB),
                        ),
                        alignment: Alignment.center,
                        child: Icon(ok ? Icons.check : Icons.error_outline, size: 16,
                            color: ok ? const Color(0xFF166534) : const Color(0xFFB91C1C)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Catégorie: ${response?['categorie'] ?? '-'}',
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('Date: ${map['created_at'] ?? '-'}',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                      Text('HTTP ${map['ml_status_code'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statusRow({required String title, required String value, required bool ok}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle : Icons.cancel_outlined,
              color: ok ? const Color(0xFF16A34A) : const Color(0xFFDC2626), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value),
        ],
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), color: const Color(0x33214BFF)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }

  String _shortMetric(dynamic value) {
    final text = (value ?? '-').toString();
    if (text.length <= 7) return text;
    return text.substring(0, 7);
  }
}

class _DashboardBackground extends StatelessWidget {
  const _DashboardBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF6F8FF), Color(0xFFEEF2FF), Color(0xFFF8FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -120, right: -80,
              child: Container(width: 320, height: 320,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x14214BFF)))),
          Positioned(bottom: -130, left: -70,
              child: Container(width: 300, height: 300,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x12000091)))),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFFF8FAFF)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF334155)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF334155))),
        ],
      ),
    );
  }
}