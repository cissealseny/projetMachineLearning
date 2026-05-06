import 'dart:async';
import 'package:flutter/material.dart';

import '../models/predict_models.dart';
import '../services/api_service.dart';

class NlpScreen extends StatefulWidget {
  const NlpScreen({super.key, required this.api});

  final ApiService api;

  @override
  State<NlpScreen> createState() => _NlpScreenState();
}

class _NlpScreenState extends State<NlpScreen> {
  static const _primaryBlue = Color(0xFF000091);
  static const _deepBlue = Color(0xFF001A6E);

  final _rapportCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  NlpResponse? _result;

  final List<String> _examples = [
    'Fragments de métal rouillé collectés sur le chantier B.',
    'Lot de plastique souple récupéré à l usine A.',
    'Bouteilles en verre brisées provenant du centre de tri.',
    'Cartons et papiers usagés issus du bureau administratif.',
    'Ferraille et câbles électriques conducteurs de forte rigidité.',
  ];

  @override
  void dispose() {
    _rapportCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _rapportCtrl.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Veuillez entrer une description avant d analyser.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      // Appel au nouvel endpoint /predict/nlp
      // Le backend injecte les médianes globales pour les features numériques
      // → seul le texte influence la prédiction
      final response = await widget.api.predictNlp(text);
      if (!mounted) return;
      setState(() => _result = response);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _useExample(String example) {
    _rapportCtrl.text = example;
    setState(() {
      _result = null;
      _error = null;
    });
  }

  Color _categoryColor(String categorie) {
    switch (categorie.toLowerCase()) {
      case 'plastique':
        return Colors.blue;
      case 'métal':
      case 'metal':
        return const Color(0xFF64748B);
      case 'verre':
        return Colors.teal;
      case 'papier':
        return Colors.orange;
      default:
        return _primaryBlue;
    }
  }

  IconData _categoryIcon(String categorie) {
    switch (categorie.toLowerCase()) {
      case 'plastique':
        return Icons.water_drop_outlined;
      case 'métal':
      case 'metal':
        return Icons.hardware_outlined;
      case 'verre':
        return Icons.wine_bar_outlined;
      case 'papier':
        return Icons.article_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth > 860;
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildInputPanel()),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: _buildResultPanel()),
                      ],
                    );
                  }
                  return Column(children: [
                    _buildInputPanel(),
                    const SizedBox(height: 14),
                    _buildResultPanel(),
                  ]);
                }),
                const SizedBox(height: 14),
                _buildPipelineExplanation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3D62), Color(0xFF0A2EA6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x290A3D62), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withOpacity(0.15),
            ),
            child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assistant Intelligent NLP',
                  style: TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.1),
                ),
                SizedBox(height: 6),
                Text(
                  'Décrivez un déchet en texte libre — le pipeline NLP classifie sans les features numériques.',
                  style: TextStyle(color: Color(0xFFDCE7FF), height: 1.45),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.text_fields, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('NLP Only',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.edit_note_outlined, color: _deepBlue),
                SizedBox(width: 8),
                Text('Description textuelle',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Saisissez une description libre du déchet. Le pipeline applique tokenisation, suppression des stopwords et stemming. Les features numériques sont neutralisées.',
              style: TextStyle(color: Color(0xFF64748B), height: 1.4, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // Zone de texte
            TextField(
              controller: _rapportCtrl,
              maxLines: 6,
              minLines: 4,
              decoration: InputDecoration(
                hintText:
                    'Ex: Fragments de métal rouillé collectés sur le chantier B...',
                hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(14),
              ),
              onChanged: (_) => setState(() {
                _result = null;
                _error = null;
              }),
            ),
            const SizedBox(height: 14),

            // Bouton analyser
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _loading ? null : _analyze,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.psychology_outlined),
                label: Text(_loading ? 'Analyse NLP en cours...' : 'Analyser via NLP'),
                style: FilledButton.styleFrom(
                  backgroundColor: _primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 12),

            const Text('Exemples rapides :',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF334155))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _examples.map((example) {
                return InkWell(
                  onTap: () => _useExample(example),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFDCE2F6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, size: 13, color: _primaryBlue),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            example.length > 45 ? '${example.substring(0, 45)}...' : example,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPanel() {
    if (_result == null && !_loading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.psychology_outlined, color: _deepBlue, size: 36),
              ),
              const SizedBox(height: 16),
              const Text('Résultat NLP',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Entrez une description et cliquez sur "Analyser via NLP".',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 20),
              _pipelineStepBadge('1. Tokenisation', Icons.short_text, false),
              const SizedBox(height: 6),
              _pipelineStepBadge('2. Stopwords supprimés', Icons.filter_alt_outlined, false),
              const SizedBox(height: 6),
              _pipelineStepBadge('3. Stemming', Icons.compress_outlined, false),
              const SizedBox(height: 6),
              _pipelineStepBadge('4. Vectorisation TF-IDF', Icons.table_chart_outlined, false),
              const SizedBox(height: 6),
              _pipelineStepBadge('5. Classification ML', Icons.model_training_outlined, false),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              const Text('Pipeline NLP en cours...',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              const Text(
                'Tokenisation → Stopwords → Stemming → TF-IDF → Classification',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    }

    final result = _result!;
    final color = _categoryColor(result.categorie);
    final icon = _categoryIcon(result.categorie);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics_outlined, color: _deepBlue),
                SizedBox(width: 8),
                Text('Résultat NLP',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),

            // Catégorie prédite
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.35), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Catégorie détectée (NLP)',
                            style: TextStyle(
                                color: color.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                        Text(
                          result.categorie,
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.w800, color: color),
                        ),
                        Text(
                          '${result.tokensCount} token${result.tokensCount > 1 ? 's' : ''} analysé${result.tokensCount > 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 14),
                        SizedBox(width: 4),
                        Text('NLP Only',
                            style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontWeight: FontWeight.w700,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Probabilités
            const Text('Probabilités par catégorie',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            ...result.probabilites.entries.map((entry) {
              final pct = (entry.value * 100);
              final isTop = entry.key == result.categorie;
              final barColor = isTop ? color : const Color(0xFF94A3B8);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            if (isTop)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(Icons.star, size: 13, color: color),
                              ),
                            Text(entry.key,
                                style: TextStyle(
                                    fontWeight: isTop ? FontWeight.w700 : FontWeight.w500,
                                    color: isTop ? color : const Color(0xFF475569))),
                          ],
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: isTop ? color : const Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: entry.value,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation(barColor),
                      minHeight: isTop ? 8 : 5,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Texte après pipeline NLP
            const Row(
              children: [
                Icon(Icons.compress_outlined, size: 16, color: _deepBlue),
                SizedBox(width: 6),
                Text('Tokens après pipeline NLP',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Résultat après tokenisation, stopwords et stemming :',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: result.texteClean.isEmpty
                  ? const Text(
                      '(texte_clean vide — texte trop court ou que des stopwords)',
                      style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontStyle: FontStyle.italic,
                          fontSize: 13),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: result.texteClean
                          .split(' ')
                          .where((t) => t.isNotEmpty)
                          .map((token) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _deepBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _deepBlue.withOpacity(0.2)),
                          ),
                          child: Text(
                            token,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _deepBlue,
                                fontFamily: 'monospace'),
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 14),

            // Pipeline complété
            const Text('Pipeline exécuté :',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            _pipelineStepBadge('Tokenisation', Icons.short_text, true),
            const SizedBox(height: 5),
            _pipelineStepBadge('Stopwords supprimés', Icons.filter_alt_outlined, true),
            const SizedBox(height: 5),
            _pipelineStepBadge('Stemming appliqué', Icons.compress_outlined, true),
            const SizedBox(height: 5),
            _pipelineStepBadge('Vectorisation TF-IDF', Icons.table_chart_outlined, true),
            const SizedBox(height: 5),
            _pipelineStepBadge('Classification ML (NLP Only)', Icons.model_training_outlined, true),

            const SizedBox(height: 12),
            // Note info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, size: 15, color: Color(0xFF166534)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      result.note,
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFF166534), height: 1.4),
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

  Widget _pipelineStepBadge(String label, IconData icon, bool done) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE8FAEE) : const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: done ? const Color(0xFFBBF7D0) : const Color(0xFFDCE2F6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : icon,
              size: 15,
              color: done ? const Color(0xFF16A34A) : const Color(0xFF94A3B8)),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: done ? const Color(0xFF166534) : const Color(0xFF94A3B8))),
        ],
      ),
    );
  }

  Widget _buildPipelineExplanation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: _deepBlue),
                SizedBox(width: 8),
                Text('Comment fonctionne ce module ?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final wide = constraints.maxWidth > 700;
              final steps = [
                _PipelineStep(
                  icon: Icons.short_text,
                  color: Colors.blue,
                  title: 'Tokenisation',
                  desc: 'Le texte est découpé en tokens (mots individuels).',
                ),
                _PipelineStep(
                  icon: Icons.filter_alt_outlined,
                  color: Colors.orange,
                  title: 'Stopwords',
                  desc: 'Les mots vides français (de, le, à…) sont supprimés.',
                ),
                _PipelineStep(
                  icon: Icons.compress_outlined,
                  color: Colors.purple,
                  title: 'Stemming',
                  desc: 'Chaque mot est réduit à sa racine (métal → metal).',
                ),
                _PipelineStep(
                  icon: Icons.table_chart_outlined,
                  color: Colors.teal,
                  title: 'TF-IDF',
                  desc: 'Les tokens sont vectorisés en représentation numérique.',
                ),
                _PipelineStep(
                  icon: Icons.model_training_outlined,
                  color: _primaryBlue,
                  title: 'Classification',
                  desc: 'Le modèle prédit la catégorie sur la base du texte seul.',
                ),
              ];
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:
                      steps.map((s) => Expanded(child: _stepCard(s))).toList(),
                );
              }
              return Column(
                children: steps
                    .map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _stepCard(s)))
                    .toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _stepCard(_PipelineStep step) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: step.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: step.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(step.icon, color: step.color, size: 20),
          const SizedBox(height: 6),
          Text(step.title,
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: step.color, fontSize: 12)),
          const SizedBox(height: 4),
          Text(step.desc,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF475569), height: 1.4)),
        ],
      ),
    );
  }
}

class _PipelineStep {
  const _PipelineStep(
      {required this.icon,
      required this.color,
      required this.title,
      required this.desc});
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
}
