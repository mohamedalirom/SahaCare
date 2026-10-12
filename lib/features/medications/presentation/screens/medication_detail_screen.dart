import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MedicationDetailScreen extends StatefulWidget {
  const MedicationDetailScreen({super.key});

  @override
  State<MedicationDetailScreen> createState() =>
      _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  String? selectedStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Détail du traitement',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF0F172A),
        ),

        actions: [
          IconButton(
            tooltip: 'Modifier',
            onPressed: () {
              context.push('/medications/edit');
            },
            icon: const Icon(
              Icons.edit_outlined,
              color: Color(0xFF0D9488),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFCCFBF1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  size: 42,
                  color: Color(0xFF0D9488),
                ),
              ),
            ),

            const SizedBox(height: 15),

            const Center(
              child: Text(
                'Doliprane',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),

            const SizedBox(height: 6),

            const Center(
              child: Text(
                'Traitement en cours',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push('/medications/edit');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D9488),
                  side: const BorderSide(
                    color: Color(0xFF0D9488),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Modifier le traitement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            _buildInformationCard(
              icon: Icons.science_outlined,
              title: 'Dosage',
              value: '500 mg',
            ),

            const SizedBox(height: 12),

            _buildInformationCard(
              icon: Icons.access_time,
              title: 'Horaire de prise',
              value: '08:00',
            ),

            const SizedBox(height: 12),

            _buildInformationCard(
              icon: Icons.calendar_today_outlined,
              title: 'Date de début',
              value: '08/10/2026',
            ),

            const SizedBox(height: 12),

            _buildInformationCard(
              icon: Icons.event_outlined,
              title: 'Date de fin',
              value: '15/10/2026',
            ),

            const SizedBox(height: 12),

            _buildInformationCard(
              icon: Icons.notifications_outlined,
              title: 'Rappel',
              value: 'Activé',
            ),

            const SizedBox(height: 30),

            const Text(
              'Prise du médicament',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Indiquez le statut de cette prise.',
              style: TextStyle(
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: _buildStatusButton(
                    label: 'Pris',
                    icon: Icons.check_circle_outline,
                    status: 'Pris',
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _buildStatusButton(
                    label: 'Reporter',
                    icon: Icons.schedule,
                    status: 'Reporté',
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: _buildStatusButton(
                    label: 'Ignorer',
                    icon: Icons.close,
                    status: 'Ignoré',
                  ),
                ),
              ],
            ),

            if (selectedStatus != null) ...[
              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFA7F3D0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF0D9488),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'Statut enregistré : $selectedStatus',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showDeleteDialog(context);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(
                    color: Color(0xFFFCA5A5),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline,
                ),
                label: const Text(
                  'Supprimer le traitement',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0D9488),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required String label,
    required IconData icon,
    required String status,
  }) {
    final bool selected = selectedStatus == status;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          selectedStatus = status;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 5,
        ),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0D9488)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF0D9488)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected
                  ? Colors.white
                  : const Color(0xFF0D9488),
            ),

            const SizedBox(height: 6),

            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Supprimer le traitement ?',
          ),
          content: const Text(
            'Voulez-vous vraiment supprimer Doliprane de vos traitements ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Annuler',
              ),
            ),

            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.go('/medications');
              },
              child: const Text(
                'Supprimer',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}