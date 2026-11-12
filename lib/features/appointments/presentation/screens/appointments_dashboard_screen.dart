import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';
import '../controllers/appointments_controller.dart';
import '../widgets/add_edit_doctor_dialog.dart';
import '../widgets/appointment_card.dart';
import '../widgets/doctor_card.dart';

/// Écran tableau de bord principal du module : Médecins & Rendez-vous
class AppointmentsDashboardScreen extends ConsumerStatefulWidget {
  const AppointmentsDashboardScreen({super.key});

  @override
  ConsumerState<AppointmentsDashboardScreen> createState() => _AppointmentsDashboardScreenState();
}

class _AppointmentsDashboardScreenState extends ConsumerState<AppointmentsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Specialty> _specialties = List.from(Specialty.mockSpecialties);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointmentsState = ref.watch(appointmentsNotifierProvider);
    final upcomingCount = appointmentsState.upcomingCount;
    final isDoctorsTab = _tabController.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Médecins & Rendez-vous'),
        actions: [
          if (isDoctorsTab)
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded),
              tooltip: 'Ajouter un médecin',
              onPressed: () => AddEditDoctorDialog.show(context),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Prendre un rendez-vous',
              onPressed: () => context.push('/appointments/book'),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: theme.colorScheme.primary,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.calendar_month_rounded, size: 20),
              text: 'Mes Rendez-vous ($upcomingCount)',
            ),
            Tab(
              icon: const Icon(Icons.people_alt_rounded, size: 20),
              text: 'Annuaire Médecins (${appointmentsState.doctors.length})',
            ),
          ],
        ),
      ),
      body: (appointmentsState.isLoading && appointmentsState.appointments.isEmpty && appointmentsState.doctors.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // ================= Onglet 1 : Mes Rendez-vous =================
                _buildAppointmentsTab(context, appointmentsState),

                // ================= Onglet 2 : Annuaire Médecins & Spécialités =================
                _buildDoctorsTab(context, appointmentsState),
              ],
            ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76.0),
        child: FloatingActionButton.extended(
          onPressed: () {
            if (isDoctorsTab) {
              AddEditDoctorDialog.show(context);
            } else {
              context.push('/appointments/book');
            }
          },
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          icon: Icon(isDoctorsTab ? Icons.person_add_alt_1_rounded : Icons.add_rounded),
          label: Text(
            isDoctorsTab ? 'Ajouter un Médecin' : 'Prendre un RDV',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentsTab(BuildContext context, AppointmentsState state) {
    final filteredAppointments = state.filteredAppointments;
    final notifier = ref.read(appointmentsNotifierProvider.notifier);

    return RefreshIndicator(
      onRefresh: () => notifier.loadData(),
      child: Column(
        children: [
          if (state.errorMessage != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          // Filtres d'état des rendez-vous
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tous'),
                  selected: state.filterStatus == null,
                  onSelected: (_) => notifier.setFilterStatus(null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('À venir'),
                  selected: state.filterStatus == AppointmentStatus.upcoming,
                  onSelected: (sel) => notifier.setFilterStatus(sel ? AppointmentStatus.upcoming : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Historique / Passés'),
                  selected: state.filterStatus == AppointmentStatus.completed,
                  onSelected: (sel) => notifier.setFilterStatus(sel ? AppointmentStatus.completed : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Annulés'),
                  selected: state.filterStatus == AppointmentStatus.cancelled,
                  onSelected: (sel) => notifier.setFilterStatus(sel ? AppointmentStatus.cancelled : null),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // En-tête avec bouton d'action évident
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${filteredAppointments.length} rendez-vous',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => context.push('/appointments/book'),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'Nouveau RDV',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ),

          // Liste des rendez-vous
          Expanded(
            child: filteredAppointments.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy_rounded, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun rendez-vous trouvé',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Cliquez sur "Prendre un RDV" pour créer votre consultation',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () => context.push('/appointments/book'),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Prendre un RDV'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: filteredAppointments.length,
                    itemBuilder: (context, index) {
                      final appointment = filteredAppointments[index];
                      return AppointmentCard(
                        appointment: appointment,
                        onTap: () {
                          context.push('/appointments/${appointment.id}', extra: appointment);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteDoctor(BuildContext context, Doctor doctor) {
    final notifier = ref.read(appointmentsNotifierProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Supprimer ce médecin ?'),
          ],
        ),
        content: Text(
          'Voulez-vous vraiment retirer ${doctor.fullName} de votre annuaire de praticiens ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await notifier.deleteDoctor(doctor.id);
              if (!context.mounted) return;
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${doctor.fullName} supprimé de l\'annuaire.'),
                    backgroundColor: Colors.black87,
                  ),
                );
              }
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctorsTab(BuildContext context, AppointmentsState state) {
    final theme = Theme.of(context);
    final notifier = ref.read(appointmentsNotifierProvider.notifier);
    final filteredDoctors = state.filteredDoctors;

    return RefreshIndicator(
      onRefresh: () => notifier.loadData(),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Barre de recherche de médecin
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: (val) => notifier.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Rechercher un médecin, spécialité, clinique...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Bannière d'orientation IA vers la bonne spécialité
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: const Color(0xFF0D9488).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => context.push('/appointments/orientation'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF0D9488), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quelle spécialité consulter ?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Décrivez vos symptômes pour être orienté par l\'IA',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF0D9488), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filtre par Spécialités
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _specialties.map((spec) {
                final isSelected = state.selectedSpecialty == spec.name;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(spec.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        notifier.setSelectedSpecialty(spec.name);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // En-tête avec bouton d'action évident
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${filteredDoctors.length} praticien(s)',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.push('/appointments/nearby'),
                  icon: const Icon(Icons.near_me_rounded, size: 16),
                  label: const Text(
                    'À proximité',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFF0D9488),
                    side: const BorderSide(color: Color(0xFF0D9488)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => AddEditDoctorDialog.show(context),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: const Text(
                    'Ajouter médecin',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
          ),

          // Liste des médecins
          Expanded(
            child: filteredDoctors.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search_rounded, size: 60, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Aucun médecin correspondant',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => AddEditDoctorDialog.show(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Ajouter un médecin'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: filteredDoctors.length,
                    itemBuilder: (context, index) {
                      final doc = filteredDoctors[index];
                      return DoctorCard(
                        doctor: doc,
                        onTap: () {
                          context.push('/doctors/${doc.id}', extra: doc);
                        },
                        onBookPressed: () {
                          context.push('/appointments/book', extra: doc);
                        },
                        onEditPressed: () {
                          AddEditDoctorDialog.show(context, doctor: doc);
                        },
                        onDeletePressed: () {
                          _confirmDeleteDoctor(context, doc);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
