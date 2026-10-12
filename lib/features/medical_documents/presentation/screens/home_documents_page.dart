import 'package:flutter/material.dart';

import '../../domain/entities/emergency_contact.dart';
import '../../domain/entities/medical_document.dart';
import '../widgets/section_header_card.dart';
import 'analyses_page.dart';
import 'emergency_contacts_page.dart';
import 'emergency_medical_card_page.dart';
import 'medical_qr_page.dart';
import 'medical_reports_page.dart';
import 'prescriptions_page.dart';

/// Écran d'accueil du module : Documents médicaux & Urgence
class HomeDocumentsPage extends StatelessWidget {
  const HomeDocumentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final documentTiles = [
      _ModuleTile(
        title: 'Ordonnances',
        subtitle: '${MedicalDocument.mockPrescriptions.length} documents',
        icon: DocumentCategory.prescription.icon,
        color: DocumentCategory.prescription.color,
        page: const PrescriptionsPage(),
      ),
      _ModuleTile(
        title: 'Analyses',
        subtitle: '${MedicalDocument.mockAnalyses.length} documents',
        icon: DocumentCategory.analysis.icon,
        color: DocumentCategory.analysis.color,
        page: const AnalysesPage(),
      ),
      _ModuleTile(
        title: 'Rapports médicaux',
        subtitle: '${MedicalDocument.mockReports.length} documents',
        icon: DocumentCategory.report.icon,
        color: DocumentCategory.report.color,
        page: const MedicalReportsPage(),
      ),
    ];

    final emergencyTiles = [
      _ModuleTile(
        title: 'Contacts d\'urgence',
        subtitle: '${EmergencyContact.mockContacts.length} contacts',
        icon: Icons.contact_phone_rounded,
        color: const Color(0xFF0EA5E9),
        page: const EmergencyContactsPage(),
      ),
      const _ModuleTile(
        title: 'Carte d\'urgence',
        subtitle: 'Informations vitales',
        icon: Icons.badge_rounded,
        color: Color(0xFFE11D48),
        page: EmergencyMedicalCardPage(),
      ),
      const _ModuleTile(
        title: 'QR Code médical',
        subtitle: 'Accès rapide',
        icon: Icons.qr_code_2_rounded,
        color: Color(0xFF0F766E),
        page: MedicalQrPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Documents & Urgence')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionHeaderCard(
            icon: Icons.folder_shared_rounded,
            title: 'Mon dossier & urgence',
            subtitle: 'Centralisez vos ordonnances, analyses et rapports, et gardez vos informations '
                'vitales accessibles en cas d\'urgence.',
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          const _SectionTitle('Documents médicaux'),
          _TileGrid(tiles: documentTiles),
          const SizedBox(height: 20),
          const _SectionTitle('Urgence'),
          _TileGrid(tiles: emergencyTiles),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
      ),
    );
  }
}

/// Grille responsive : 2 colonnes sur téléphone, 3 sur écran plus large
class _TileGrid extends StatelessWidget {
  final List<_ModuleTile> tiles;

  const _TileGrid({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        crossAxisCount: constraints.maxWidth >= 520 ? 3 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
        children: tiles,
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;

  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const Spacer(),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}
