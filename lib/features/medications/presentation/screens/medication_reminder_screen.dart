import 'package:flutter/material.dart';

class MedicationReminderScreen extends StatefulWidget {
  const MedicationReminderScreen({super.key});

  @override
  State<MedicationReminderScreen> createState() =>
      _MedicationReminderScreenState();
}

class _MedicationReminderScreenState
    extends State<MedicationReminderScreen> {
  bool dolipraneReminder = true;
  bool amoxicillineReminder = true;
  bool vitamineReminder = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Rappels de médicaments',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF0F172A),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mes rappels',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Activez ou désactivez les rappels de vos traitements.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 25),

            _buildReminderCard(
              medication: 'Doliprane',
              dosage: '500 mg',
              time: '08:00',
              value: dolipraneReminder,
              onChanged: (value) {
                setState(() {
                  dolipraneReminder = value;
                });
              },
            ),

            const SizedBox(height: 12),

            _buildReminderCard(
              medication: 'Amoxicilline',
              dosage: '1 comprimé',
              time: '14:00',
              value: amoxicillineReminder,
              onChanged: (value) {
                setState(() {
                  amoxicillineReminder = value;
                });
              },
            ),

            const SizedBox(height: 12),

            _buildReminderCard(
              medication: 'Vitamine D',
              dosage: '1 dose',
              time: '20:00',
              value: vitamineReminder,
              onChanged: (value) {
                setState(() {
                  vitamineReminder = value;
                });
              },
            ),

            const SizedBox(height: 30),

            const Text(
              'Informations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFA7F3D0),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF0D9488),
                  ),

                  SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      'Les rappels vous aident à respecter les horaires de vos traitements.',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        height: 1.4,
                      ),
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

  Widget _buildReminderCard({
    required String medication,
    required String dosage,
    required String time,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Color(0xFF0D9488),
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$dosage • $time',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: value,
            activeColor: const Color(0xFF0D9488),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}