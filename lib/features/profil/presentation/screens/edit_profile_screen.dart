import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Youssef User');
  double _height = 180.0;
  double _weight = 75.0;
  String _selectedBloodGroup = 'O';
  String _selectedRhesus = '+';
  bool _isLoading = false;

  final List<String> bloodGroups = ['A', 'B', 'AB', 'O'];
  final List<String> rhesusFactors = ['+', '-'];

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _isLoading = false);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Informations Personnelles', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nom complet',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              
              Text('Données Physiologiques', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18)),
              const SizedBox(height: 16),
              
              // Taille
              Text('Taille : ${_height.toInt()} cm', style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _height,
                min: 100,
                max: 250,
                activeColor: AppTheme.primaryColor,
                onChanged: (val) => setState(() => _height = val),
              ),
              
              // Poids
              Text('Poids : ${_weight.toInt()} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _weight,
                min: 30,
                max: 200,
                activeColor: AppTheme.secondaryColor,
                onChanged: (val) => setState(() => _weight = val),
              ),
              
              const SizedBox(height: 16),
              // Groupe Sanguin
              Text('Groupe Sanguin', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: bloodGroups.map((bg) => ButtonSegment(value: bg, label: Text(bg))).toList(),
                      selected: {_selectedBloodGroup},
                      onSelectionChanged: (set) => setState(() => _selectedBloodGroup = set.first),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<String>(
                    segments: rhesusFactors.map((r) => ButtonSegment(value: r, label: Text(r))).toList(),
                    selected: {_selectedRhesus},
                    onSelectionChanged: (set) => setState(() => _selectedRhesus = set.first),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  label: 'Enregistrer les modifications',
                  onPressed: _saveProfile,
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
