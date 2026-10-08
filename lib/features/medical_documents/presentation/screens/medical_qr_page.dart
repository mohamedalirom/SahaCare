import 'package:flutter/material.dart';

import '../../domain/entities/emergency_profile.dart';

/// QR code médical d'urgence. Le QR affiché est un motif fictif dessiné localement :
/// aucune génération réelle de QR code pour le moment.
class MedicalQrPage extends StatelessWidget {
  const MedicalQrPage({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = EmergencyProfile.mock;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('QR Code médical')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text(
                    'Scannez en cas d\'urgence',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Ce code donne accès uniquement aux informations que vous avez autorisées.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                    ),
                    child: SizedBox.square(
                      dimension: 210,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(size: const Size.square(210), painter: _FakeQrPainter()),
                          Container(
                            width: 46,
                            height: 46,
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Aperçu — QR code fictif (démo)',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shield_rounded, color: primary, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Informations partagées en cas d\'urgence',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SharedInfoRow(icon: Icons.person_rounded, label: 'Nom', value: profile.fullName),
                  _SharedInfoRow(icon: Icons.bloodtype_rounded, label: 'Groupe sanguin', value: profile.bloodGroup),
                  _SharedInfoRow(
                    icon: Icons.warning_amber_rounded,
                    label: 'Allergies',
                    value: profile.allergies.join(', '),
                  ),
                  _SharedInfoRow(
                    icon: Icons.phone_in_talk_rounded,
                    label: 'Contact d\'urgence',
                    value: '${profile.contact.name} · ${profile.contact.phone}',
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Vos documents médicaux ne sont jamais partagés via ce QR code.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Retour'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ],
      ),
    );
  }
}

class _SharedInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _SharedInfoRow({required this.icon, required this.label, required this.value, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dessine un faux QR code : 3 repères d'angle + motif pseudo-aléatoire fixe
class _FakeQrPainter extends CustomPainter {
  static const _modules = 25;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / _modules;
    final dark = Paint()..color = const Color(0xFF0F172A);

    for (var y = 0; y < _modules; y++) {
      for (var x = 0; x < _modules; x++) {
        if (_isInFinderZone(x, y)) continue;
        if (((x * 73856093) ^ (y * 19349663)) % 7 < 3) {
          canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), dark);
        }
      }
    }

    _drawFinder(canvas, dark, 0, 0, cell);
    _drawFinder(canvas, dark, _modules - 7, 0, cell);
    _drawFinder(canvas, dark, 0, _modules - 7, cell);
  }

  bool _isInFinderZone(int x, int y) {
    bool inBox(int ox, int oy) => x >= ox && x < ox + 8 && y >= oy && y < oy + 8;
    return inBox(0, 0) || inBox(_modules - 8, 0) || inBox(0, _modules - 8);
  }

  void _drawFinder(Canvas canvas, Paint paint, int col, int row, double cell) {
    final origin = Offset(col * cell, row * cell);
    canvas.drawRect(origin & Size.square(cell * 7), paint);
    canvas.drawRect((origin + Offset(cell, cell)) & Size.square(cell * 5), Paint()..color = Colors.white);
    canvas.drawRect((origin + Offset(cell * 2, cell * 2)) & Size.square(cell * 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
