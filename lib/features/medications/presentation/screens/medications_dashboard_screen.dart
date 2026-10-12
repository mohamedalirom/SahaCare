import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MedicationsDashboardScreen extends StatelessWidget {
  const MedicationsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Médicaments & Traitements',
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
              'Mes traitements',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 6),

            const Text(
              'Gérez vos médicaments, horaires et rappels.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
              ),
            ),

            const SizedBox(height: 25),

            // ================================================================
            // Médicament
            // ================================================================
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                context.push('/medications/detail');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundColor: Color(0xFFCCFBF1),
                      child: Icon(
                        Icons.medication_outlined,
                        color: Color(0xFF0D9488),
                        size: 28,
                      ),
                    ),

                    SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doliprane',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),

                          SizedBox(height: 5),

                          Text(
                            '500 mg • 08:00',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),

            // ================================================================
            // Aujourd'hui
            // ================================================================
            const Text(
              'Aujourd’hui',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 15),

            _buildTodayCard(
              time: '08:00',
              medication: 'Doliprane',
              dosage: '500 mg',
              status: 'Pris',
              statusColor: const Color(0xFF16A34A),
              statusBackground: const Color(0xFFDCFCE7),
              icon: Icons.check_circle_outline,
            ),

            const SizedBox(height: 12),

            _buildTodayCard(
              time: '14:00',
              medication: 'Amoxicilline',
              dosage: '1 comprimé',
              status: 'À prendre',
              statusColor: const Color(0xFFD97706),
              statusBackground: const Color(0xFFFEF3C7),
              icon: Icons.schedule,
            ),

            const SizedBox(height: 12),

            _buildTodayCard(
              time: '20:00',
              medication: 'Doliprane',
              dosage: '500 mg',
              status: 'À venir',
              statusColor: const Color(0xFF64748B),
              statusBackground: const Color(0xFFF1F5F9),
              icon: Icons.nightlight_outlined,
            ),

            const SizedBox(height: 30),

            // ================================================================
            // Accès rapide
            // ================================================================
            const Text(
              'Accès rapide',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),

            const SizedBox(height: 15),

            // Horaires de prise
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                context.push('/medications/schedule');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: Color(0xFFCCFBF1),
                      child: Icon(
                        Icons.access_time,
                        color: Color(0xFF0D9488),
                      ),
                    ),

                    SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Horaires de prise',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'Consulter le planning des médicaments',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Rappels
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                context.push('/medications/reminders');
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: Color(0xFFCCFBF1),
                      child: Icon(
                        Icons.notifications_outlined,
                        color: Color(0xFF0D9488),
                      ),
                    ),

                    SizedBox(width: 15),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rappels',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),

                          SizedBox(height: 4),

                          Text(
                            'Gérer les notifications de prise',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Icon(
                      Icons.chevron_right,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        onPressed: () {
          context.push('/medications/add');
        },
        icon: const Icon(Icons.add),
        label: const Text(
          'Ajouter',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard({
    required String time,
    required String medication,
    required String dosage,
    required String status,
    required Color statusColor,
    required Color statusBackground,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFCCFBF1),
              borderRadius: BorderRadius.circular(13),
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
                  '$time • $medication',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  dosage,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}