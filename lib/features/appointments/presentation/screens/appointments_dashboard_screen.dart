import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';
import '../controllers/appointments_controller.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Médecins & Rendez-vous'),
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
            const Tab(
              icon: Icon(Icons.people_alt_rounded, size: 20),
              text: 'Annuaire Médecins',
            ),
          ],
        ),
      ),
      body: (appointmentsState.isLoading && appointmentsState.appointments.isEmpty)
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/appointments/book');
        },
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Prendre un RDV',
          style: TextStyle(fontWeight: FontWeight.w600),
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
          const SizedBox(height: 12),

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

  Widget _buildDoctorsTab(BuildContext context, AppointmentsState state) {
    final theme = Theme.of(context);
    final notifier = ref.read(appointmentsNotifierProvider.notifier);
    final filteredDoctors = state.filteredDoctors;

    return Column(
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
        const SizedBox(height: 12),

        // Liste des médecins
        Expanded(
          child: filteredDoctors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun médecin correspondant',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
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
                    );
                  },
                ),
        ),
      ],
    );
  }
}
