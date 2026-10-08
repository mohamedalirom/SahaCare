import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/disease.dart';
import '../widgets/disease_card.dart';

/// Écran principal du module : Liste des maladies et affections médicales
class DiseasesListScreen extends StatefulWidget {
  const DiseasesListScreen({super.key});

  @override
  State<DiseasesListScreen> createState() => _DiseasesListScreenState();
}

class _DiseasesListScreenState extends State<DiseasesListScreen> {
  final List<Disease> _diseases = List.from(Disease.mockDiseases);
  String _searchQuery = '';
  DiseaseStatus? _selectedFilter;

  List<Disease> get _filteredDiseases {
    return _diseases.where((disease) {
      final matchesQuery = disease.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          disease.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          disease.treatingDoctor.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesStatus = _selectedFilter == null || disease.status == _selectedFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final totalActive = _diseases.where((d) => d.status == DiseaseStatus.active || d.status == DiseaseStatus.inTreatment || d.status == DiseaseStatus.chronic).length;
    final totalChronic = _diseases.where((d) => d.status == DiseaseStatus.chronic).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Affections & Maladies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'À propos du suivi médical',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Suivi des Maladies'),
                  content: const Text(
                    'Ce module vous permet de centraliser vos antécédents médicaux, affections chroniques et diagnostics pour faciliter vos échanges avec vos professionnels de santé.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Compris'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bandeau récapitulatif / Statistiques rapides
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total suivies', '${_diseases.length}', Colors.white),
                Container(height: 30, width: 1, color: Colors.white24),
                _buildStatItem('En cours', '$totalActive', Colors.white),
                Container(height: 30, width: 1, color: Colors.white24),
                _buildStatItem('Chroniques', '$totalChronic', Colors.white),
              ],
            ),
          ),

          // Barre de recherche
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher une maladie, un médecin...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Filtres rapides (Chips)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: _selectedFilter == null,
                  onSelected: (_) => setState(() => _selectedFilter = null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Chroniques'),
                  selected: _selectedFilter == DiseaseStatus.chronic,
                  onSelected: (selected) => setState(() => _selectedFilter = selected ? DiseaseStatus.chronic : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('En traitement'),
                  selected: _selectedFilter == DiseaseStatus.inTreatment,
                  onSelected: (selected) => setState(() => _selectedFilter = selected ? DiseaseStatus.inTreatment : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Actifs'),
                  selected: _selectedFilter == DiseaseStatus.active,
                  onSelected: (selected) => setState(() => _selectedFilter = selected ? DiseaseStatus.active : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Guéries'),
                  selected: _selectedFilter == DiseaseStatus.recovered,
                  onSelected: (selected) => setState(() => _selectedFilter = selected ? DiseaseStatus.recovered : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Liste des maladies
          Expanded(
            child: _filteredDiseases.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Aucune affection trouvée',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: _filteredDiseases.length,
                    itemBuilder: (context, index) {
                      final disease = _filteredDiseases[index];
                      return DiseaseCard(
                        disease: disease,
                        onTap: () {
                          context.push('/diseases/${disease.id}', extra: disease);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/diseases/add');
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Ajouter une affection',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}
