import 'package:flutter/material.dart';

import '../models/predict_models.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiService();

  final _usernameCtrl = TextEditingController(text: 'admin');
  final _passwordCtrl = TextEditingController(text: 'admin');

  final _poidsCtrl = TextEditingController(text: '25');
  final _volumeCtrl = TextEditingController(text: '50');
  final _conductiviteCtrl = TextEditingController(text: '3.5');
  final _opaciteCtrl = TextEditingController(text: '0.7');
  final _rigiditeCtrl = TextEditingController(text: '4.2');
  final _prixCtrl = TextEditingController(text: '12');
  final _sourceCtrl = TextEditingController(text: 'Usine_A');
  final _rapportCtrl = TextEditingController(
    text: 'Lot de plastique recupere a l usine A.',
  );

  bool _loading = false;
  bool _authLoading = false;
  bool _dashboardLoading = false;
  bool _authenticated = false;

  String? _error;
  String? _authError;
  String? _dashboardError;
  String? _authInfo;
  String? _publicHealthStatus;

  Map<String, dynamic>? _dashboard;
  PredictResponse? _result;

  @override
  void initState() {
    super.initState();
    _loadPublicHealth();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _poidsCtrl.dispose();
    _volumeCtrl.dispose();
    _conductiviteCtrl.dispose();
    _opaciteCtrl.dispose();
    _rigiditeCtrl.dispose();
    _prixCtrl.dispose();
    _sourceCtrl.dispose();
    _rapportCtrl.dispose();
    super.dispose();
  }

  double? _toDouble(String value) => double.tryParse(value);

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

  Future<void> _login() async {
    setState(() {
      _authLoading = true;
      _authError = null;
      _authInfo = null;
    });

    try {
      await _api.login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      setState(() {
        _authenticated = true;
        _authInfo = 'Connexion reussie.';
      });
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authenticated = false;
        _authError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() => _authLoading = false);
    }
  }

  Future<void> _quickLogin() async {
    setState(() {
      _authLoading = true;
      _authError = null;
      _authInfo = null;
    });

    try {
      final response = await _api.quickLogin();
      if (!mounted) return;
      setState(() {
        _authenticated = true;
        _authInfo =
            'Connexion demo active: ${response['username']} / ${response['password']}';
      });
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _authenticated = false;
        _authError = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() => _authLoading = false);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final request = PredictRequest(
        poids: _toDouble(_poidsCtrl.text)!,
        volume: _toDouble(_volumeCtrl.text)!,
        conductivite: _toDouble(_conductiviteCtrl.text)!,
        opacite: _toDouble(_opaciteCtrl.text)!,
        rigidite: _toDouble(_rigiditeCtrl.text)!,
        prixRevente: _toDouble(_prixCtrl.text)!,
        source: _sourceCtrl.text.trim(),
        rapportCollecte: _rapportCtrl.text.trim(),
      );

      final response = await _api.predict(request);
      if (!mounted) return;
      setState(() => _result = response);
      await _loadDashboard();
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
    setState(() {
      _authenticated = false;
      _dashboard = null;
      _result = null;
      _authInfo = 'Session fermee.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final summary = (_dashboard?['summary'] as Map<String, dynamic>?) ?? {};
    final ml = (_dashboard?['ml'] as Map<String, dynamic>?) ?? {};
    final metrics = (ml['metrics'] as Map<String, dynamic>?) ?? {};
    final recent = (_dashboard?['recent_predictions'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eco-Smart Dashboard'),
        actions: [
          IconButton(
            onPressed: _loadPublicHealth,
            icon: const Icon(Icons.health_and_safety_outlined),
            tooltip: 'Verifier etat API',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionCard(
                    title: 'Connexion',
                    subtitle:
                        'API publique status: ${_publicHealthStatus ?? 'chargement...'}',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _textField(_usernameCtrl, 'Username'),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _textField(_passwordCtrl, 'Password'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            FilledButton.icon(
                              onPressed: _authLoading ? null : _login,
                              icon: const Icon(Icons.login),
                              label: Text(
                                _authLoading ? 'Connexion...' : 'Se connecter',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _authLoading ? null : _quickLogin,
                              icon: const Icon(Icons.bolt_outlined),
                              label: const Text('Connexion demo immediate'),
                            ),
                            if (_authenticated)
                              TextButton.icon(
                                onPressed: _logout,
                                icon: const Icon(Icons.logout),
                                label: const Text('Se deconnecter'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _authenticated
                                ? 'Statut: authentifie'
                                : 'Statut: non authentifie',
                            style: TextStyle(
                              color: _authenticated
                                  ? Colors.green.shade700
                                  : Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_authInfo != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _authInfo!,
                              style: const TextStyle(color: Colors.blueGrey),
                            ),
                          ),
                        if (_authError != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _authError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Tableau de bord',
                    subtitle: 'KPIs operationnels et etat modele',
                    trailing: IconButton(
                      onPressed: (!_authenticated || _dashboardLoading)
                          ? null
                          : _loadDashboard,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualiser tableau de bord',
                    ),
                    child: !_authenticated
                        ? const Text(
                            'Connecte-toi pour charger le tableau de bord.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_dashboardLoading)
                                const LinearProgressIndicator(),
                              if (_dashboardError != null)
                                Text(
                                  _dashboardError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _metricCard(
                                    title: 'Predictions',
                                    value:
                                        '${summary['predictions_count'] ?? 0}',
                                    icon: Icons.analytics_outlined,
                                  ),
                                  _metricCard(
                                    title: 'Success rate',
                                    value: '${summary['success_rate'] ?? 0}%',
                                    icon: Icons.check_circle_outline,
                                  ),
                                  _metricCard(
                                    title: 'Modele',
                                    value: (ml['model_ready'] == true)
                                        ? 'Pret'
                                        : 'Indisponible',
                                    icon: Icons.model_training_outlined,
                                  ),
                                  _metricCard(
                                    title: 'Accuracy',
                                    value:
                                        ((metrics['accuracy'] ?? '-')
                                                .toString())
                                            .substring(
                                              0,
                                              ((metrics['accuracy'] ?? '-')
                                                          .toString()
                                                          .length >=
                                                      6)
                                                  ? 6
                                                  : (metrics['accuracy'] ?? '-')
                                                        .toString()
                                                        .length,
                                            ),
                                    icon: Icons.speed_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Dernieres predictions',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              if (recent.isEmpty)
                                const Text('Aucune prediction enregistree.')
                              else
                                ...recent.map((item) {
                                  final map = item as Map<String, dynamic>;
                                  final response =
                                      (map['response_payload']
                                          as Map<String, dynamic>?);
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.insights_outlined,
                                    ),
                                    title: Text(
                                      'Categorie: ${response?['categorie'] ?? '-'}',
                                    ),
                                    subtitle: Text(
                                      'Date: ${map['created_at'] ?? '-'} | Status: ${map['ml_status_code'] ?? '-'}',
                                    ),
                                  );
                                }),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    title: 'Nouvelle prediction',
                    subtitle: 'Saisie operationnelle des donnees de collecte',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _field(_poidsCtrl, 'Poids'),
                            _field(_volumeCtrl, 'Volume'),
                            _field(_conductiviteCtrl, 'Conductivite'),
                            _field(_opaciteCtrl, 'Opacite'),
                            _field(_rigiditeCtrl, 'Rigidite'),
                            _field(_prixCtrl, 'Prix_Revente'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _textField(_sourceCtrl, 'Source'),
                        const SizedBox(height: 12),
                        _textField(
                          _rapportCtrl,
                          'Rapport_Collecte',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: (_loading || !_authenticated)
                              ? null
                              : _submit,
                          icon: const Icon(Icons.play_arrow_outlined),
                          label: Text(_loading ? 'Prediction...' : 'Predire'),
                        ),
                        const SizedBox(height: 12),
                        if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        if (_result != null) ...[
                          Text(
                            'Categorie predite: ${_result!.categorie}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text('Texte nettoye: ${_result!.texteClean}'),
                          const SizedBox(height: 6),
                          const Text('Probabilites'),
                          ..._result!.probabilites.entries.map(
                            (e) => Text(' - ${e.key}: ${e.value}'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFF3F8F6),
          border: Border.all(color: const Color(0xFFD9E8E3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF0B8A6F)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label) {
    return SizedBox(
      width: 200,
      child: _textField(controller, label, keyboardType: TextInputType.number),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Champ requis';
        }
        if (keyboardType == TextInputType.number &&
            double.tryParse(value) == null) {
          return 'Nombre invalide';
        }
        return null;
      },
    );
  }
}
