import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Page d'accueil initiale de SahaCare
/// Présente le tableau de bord des modules de l'application
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SahaCare'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de bienvenue
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.health_and_safety_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour 👋',
                            style: TextStyle(fontSize: 16, color: Colors.white70),
                          ),
                          Text(
                            'Espace Santé Personnel',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Suivez vos affections, vos prescriptions et vos rendez-vous médicaux en toute simplicité.',
                    style: TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Titre de section
            const Text(
              'Modules Disponibles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 14),

            // Module : Gestion des maladies
            _buildModuleCard(
              context: context,
              title: 'Gestion des Maladies & Affections',
              subtitle: 'Suivi des antécédents, diagnostics, traitements et sévérités.',
              icon: Icons.coronavirus_outlined,
              iconColor: const Color(0xFF0D9488),
              badgeText: 'Disponible',
              badgeColor: const Color(0xFFDCFCE7),
              badgeTextColor: const Color(0xFF16A34A),
              onTap: () {
                context.push('/diseases');
              },
            ),
            const SizedBox(height: 14),

            // Placeholders pour les modules des autres développeurs
            _buildModuleCard(
              context: context,
              title: 'Gestion des Médicaments',
              subtitle: 'Module en cours de développement par l\'équipe.',
              icon: Icons.medication_liquid_outlined,
              iconColor: const Color(0xFF64748B),
              badgeText: 'Bientôt',
              badgeColor: const Color(0xFFF1F5F9),
              badgeTextColor: const Color(0xFF64748B),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Module Médicaments en cours de développement')),
                );
              },
            ),
            const SizedBox(height: 14),

            _buildModuleCard(
              context: context,
              title: 'Rendez-vous & Consultations',
              subtitle: 'Module en cours de développement par l\'équipe.',
              icon: Icons.calendar_month_outlined,
              iconColor: const Color(0xFF64748B),
              badgeText: 'Bientôt',
              badgeColor: const Color(0xFFF1F5F9),
              badgeTextColor: const Color(0xFF64748B),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Module Rendez-vous en cours de développement')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: badgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }
}
