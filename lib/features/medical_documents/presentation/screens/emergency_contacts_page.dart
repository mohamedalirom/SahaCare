import 'package:flutter/material.dart';

import '../../domain/entities/emergency_contact.dart';
import '../widgets/section_header_card.dart';
import 'add_emergency_contact_page.dart';

/// Liste des contacts d'urgence (données fictives)
class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});

  void _openForm(BuildContext context, [EmergencyContact? contact]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddEmergencyContactPage(contact: contact)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const contacts = EmergencyContact.mockContacts;

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts d\'urgence')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Ajouter un contact',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const SectionHeaderCard(
            icon: Icons.contact_phone_rounded,
            title: 'Mes contacts d\'urgence',
            subtitle: 'Ces personnes apparaissent sur votre carte médicale et votre QR code.',
            color: Color(0xFF0284C7),
          ),
          const SizedBox(height: 16),
          ...contacts.map(
            (c) => _ContactCard(contact: c, onEdit: () => _openForm(context, c)),
          ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final VoidCallback onEdit;

  const _ContactCard({required this.contact, required this.onEdit});

  /// Confirmation de suppression purement visuelle : rien n'est supprimé
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
        title: const Text('Supprimer ce contact ?'),
        content: Text('${contact.name} ne sera plus affiché(e) sur votre carte d\'urgence.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression simulée (démo)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0284C7);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(
                    contact.initials,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Badge(text: contact.relation, background: const Color(0xFFE0F2FE), foreground: color),
                          if (contact.isPrimary)
                            const _Badge(
                              text: 'Principal',
                              background: Color(0xFFDCFCE7),
                              foreground: Color(0xFF16A34A),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(icon: Icons.phone_rounded, text: contact.phone),
            if (contact.email != null) ...[
              const SizedBox(height: 4),
              _InfoLine(icon: Icons.email_outlined, text: contact.email!),
            ],
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Modifier'),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
                  onPressed: () => _confirmDelete(context),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _Badge({required this.text, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: foreground)),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
        ),
      ],
    );
  }
}
