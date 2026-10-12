import 'package:flutter/material.dart';

import '../../../../core/utils/app_utils.dart';
import '../../domain/entities/emergency_profile.dart';
import '../widgets/form_widgets.dart';
import 'medical_qr_page.dart';

/// Carte médicale d'urgence générée à partir des informations du patient (données fictives)
class EmergencyMedicalCardPage extends StatelessWidget {
  const EmergencyMedicalCardPage({super.key});

  static const _red = Color(0xFFE11D48);

  void _showEditSheet(BuildContext context, EmergencyProfile profile) {
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Modifier la carte d\'urgence',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 16),
                const FormFieldLabel('Groupe sanguin'),
                DropdownButtonFormField<String>(
                  initialValue: profile.bloodGroup,
                  decoration: formInputDecoration(icon: Icons.bloodtype_rounded),
                  items: EmergencyProfile.bloodGroups
                      .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                      .toList(),
                  onChanged: (_) {},
                ),
                const SizedBox(height: 14),
                const FormFieldLabel('Allergies'),
                TextFormField(
                  initialValue: profile.allergies.join(', '),
                  decoration: formInputDecoration(icon: Icons.warning_amber_rounded),
                ),
                const SizedBox(height: 14),
                const FormFieldLabel('Maladies importantes'),
                TextFormField(
                  initialValue: profile.conditions.join(', '),
                  decoration: formInputDecoration(icon: Icons.healing_rounded),
                ),
                const SizedBox(height: 14),
                const FormFieldLabel('Médicaments importants'),
                TextFormField(
                  initialValue: profile.medications.join(', '),
                  decoration: formInputDecoration(icon: Icons.medication_rounded),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Carte d\'urgence mise à jour (démo)'),
                        backgroundColor: Color(0xFF16A34A),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = EmergencyProfile.mock;
    final contact = profile.contact;

    return Scaffold(
      appBar: AppBar(title: const Text('Carte d\'urgence')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: _red.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bandeau rouge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_red, Color(0xFFF43F5E)]),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.emergency_rounded, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'CARTE MÉDICALE D\'URGENCE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Icon(Icons.local_hospital_rounded, color: Colors.white70),
                    ],
                  ),
                ),

                // Identité + groupe sanguin
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.fullName,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Né le ${AppUtils.formatDate(profile.birthDate)} · ${profile.age} ans',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 72,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.water_drop_rounded, color: _red, size: 20),
                            Text(
                              profile.bloodGroup,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _red),
                            ),
                            const Text('Groupe', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                _CardSection(
                  icon: Icons.warning_amber_rounded,
                  color: const Color(0xFFF59E0B),
                  title: 'Allergies',
                  child: _Chips(items: profile.allergies, color: const Color(0xFFDC2626)),
                ),
                _CardSection(
                  icon: Icons.healing_rounded,
                  color: const Color(0xFF0284C7),
                  title: 'Maladies importantes',
                  child: _Chips(items: profile.conditions, color: const Color(0xFF0284C7)),
                ),
                _CardSection(
                  icon: Icons.medication_rounded,
                  color: const Color(0xFF0D9488),
                  title: 'Médicaments importants',
                  child: _Chips(items: profile.medications, color: const Color(0xFF0D9488)),
                ),
                _CardSection(
                  icon: Icons.phone_in_talk_rounded,
                  color: const Color(0xFF16A34A),
                  title: 'Contact d\'urgence',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${contact.name} (${contact.relation})',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      Text(contact.phone, style: const TextStyle(color: Color(0xFF334155))),
                    ],
                  ),
                ),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  color: const Color(0xFFF8FAFC),
                  child: Text(
                    'Dernière mise à jour : ${AppUtils.formatDate(profile.updatedAt)}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditSheet(context, profile),
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Modifier'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MedicalQrPage()),
                  ),
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Afficher QR Code'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Widget child;

  const _CardSection({required this.icon, required this.color, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                child,
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  final List<String> items;
  final Color color;

  const _Chips({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(item, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ),
          )
          .toList(),
    );
  }
}
