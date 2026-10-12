import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Note: Use Riverpod state here for real data.
    final height = 180.0;
    final weight = 75.0;
    final bmi = weight / ((height / 100) * (height / 100));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/edit-profil'),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Header: Avatar & Info
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.person, size: 50, color: Colors.white),
                    // backgroundImage: NetworkImage('...'),
                  ),
                  const SizedBox(height: 16),
                  Text('Youssef User', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('youssef@sahacare.tn', style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Vitals Grid
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildVitalCard(context, 'Groupe Sanguin', 'O+', Icons.bloodtype, Colors.redAccent),
                _buildVitalCard(context, 'Taille', '${height.toInt()} cm', Icons.height, Colors.blueAccent),
                _buildVitalCard(context, 'Poids', '${weight.toInt()} kg', Icons.monitor_weight, Colors.orange),
                _buildVitalCard(context, 'IMC', bmi.toStringAsFixed(1), Icons.fitness_center, AppTheme.primaryColor),
              ],
            ),
            const SizedBox(height: 32),
            
            // Medical Record Link
            Card(
              child: ListTile(
                leading: const Icon(Icons.folder_shared, color: AppTheme.primaryColor),
                title: const Text('Dossier Médical'),
                subtitle: const Text('Maladies, Allergies, Antécédents'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/medical-records'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
