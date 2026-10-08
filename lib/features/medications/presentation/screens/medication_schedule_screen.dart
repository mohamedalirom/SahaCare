import 'package:flutter/material.dart';

class MedicationScheduleScreen extends StatelessWidget {
  const MedicationScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Horaires de prise',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFF0F172A),
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Planning du jour',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Consultez les heures prévues pour vos traitements.',
            style: TextStyle(
              color: Color(0xFF64748B),
            ),
          ),

          const SizedBox(height: 25),

          _buildScheduleCard(
            time: '08:00',
            medication: 'Doliprane',
            dosage: '500 mg',
            icon: Icons.wb_sunny_outlined,
          ),

          const SizedBox(height: 12),

          _buildScheduleCard(
            time: '14:00',
            medication: 'Amoxicilline',
            dosage: '1 comprimé',
            icon: Icons.wb_sunny,
          ),

          const SizedBox(height: 12),

          _buildScheduleCard(
            time: '20:00',
            medication: 'Doliprane',
            dosage: '500 mg',
            icon: Icons.nightlight_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard({
    required String time,
    required String medication,
    required String dosage,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF0D9488),
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '$medication • $dosage',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons.schedule,
            color: Color(0xFF0D9488),
          ),
        ],
      ),
    );
  }
}