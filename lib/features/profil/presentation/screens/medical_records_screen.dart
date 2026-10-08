import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/add_disease_sheet.dart';
import '../widgets/add_allergy_sheet.dart';

class MedicalRecordsScreen extends ConsumerStatefulWidget {
  const MedicalRecordsScreen({super.key});

  @override
  ConsumerState<MedicalRecordsScreen> createState() => _MedicalRecordsScreenState();
}

class _MedicalRecordsScreenState extends ConsumerState<MedicalRecordsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dossier Médical'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondaryColor,
          indicatorColor: AppTheme.primaryColor,
          tabs: const [
            Tab(text: 'Maladies'),
            Tab(text: 'Allergies'),
            Tab(text: 'Antécédents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiseasesTab(),
          _buildAllergiesTab(),
          _buildHistoryTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () {
          if (_tabController.index == 0) {
            showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const AddDiseaseSheet());
          } else if (_tabController.index == 1) {
            showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const AddAllergySheet());
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildDiseasesTab() {
    // Fake data for UI structure
    final diseases = ['Hypertension', 'Diabète Type 2'];
    
    if (diseases.isEmpty) {
      return const Center(child: Text('Aucune maladie enregistrée.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: diseases.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          child: ListTile(
            leading: const Icon(Icons.coronavirus, color: Colors.redAccent),
            title: Text(diseases[index], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Diagnostiqué en 2021'),
            trailing: const Chip(
              label: Text('Chronique', style: TextStyle(color: Colors.white, fontSize: 10)),
              backgroundColor: Colors.orange,
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllergiesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: [
          InputChip(
            label: const Text('Pénicilline'),
            avatar: const Icon(Icons.medication, size: 18),
            onDeleted: () {},
            backgroundColor: Colors.red.shade100,
          ),
          InputChip(
            label: const Text('Arachides'),
            avatar: const Icon(Icons.restaurant, size: 18),
            onDeleted: () {},
            backgroundColor: Colors.orange.shade100,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildTimelineItem('Appendicectomie', 'Opération chirurgicale', 'Mai 2015'),
        _buildTimelineItem('Fracture du poignet', 'Plâtre pendant 4 semaines', 'Août 2018'),
      ],
    );
  }

  Widget _buildTimelineItem(String title, String desc, String date) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(color: AppTheme.secondaryColor, shape: BoxShape.circle),
            ),
            Container(
              width: 2,
              height: 50,
              color: Colors.grey.shade300,
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(desc, style: Theme.of(context).textTheme.bodyMedium),
              Text(date, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}
