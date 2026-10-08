import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/doctor.dart';
import '../widgets/appointment_card.dart';
import '../widgets/doctor_card.dart';

/// Écran tableau de bord principal du module : Médecins & Rendez-vous
class AppointmentsDashboardScreen extends StatefulWidget {
  const AppointmentsDashboardScreen({super.key});

  @override
  State<AppointmentsDashboardScreen> createState() => _AppointmentsDashboardScreenState();
}

class _AppointmentsDashboardScreenState extends State<AppointmentsDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Appointment> _appointments = List.from(Appointment.mockAppointments);
  final List<Doctor> _doctors = List.from(Doctor.mockDoctors);
  final List<Specialty> _specialties = List.from(Specialty.mockSpecialties);

  String _doctorSearchQuery = '';
  String _selectedSpecialty = 'Toutes';
  AppointmentStatus? _appointmentFilter;

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

  List<Appointment> get _filteredAppointments {
    if (_appointmentFilter == null) return _appointments;
    return _appointments.where((a) => a.status == _appointmentFilter).toList();
  }

  List<Doctor> get _filteredDoctors {
    return _doctors.where((doctor) {
      final matchesQuery = doctor.fullName.toLowerCase().contains(_doctorSearchQuery.toLowerCase()) ||
          doctor.specialty.toLowerCase().contains(_doctorSearchQuery.toLowerCase()) ||
          doctor.hospitalOrClinic.toLowerCase().contains(_doctorSearchQuery.toLowerCase());
      final matchesSpecialty = _selectedSpecialty == 'Toutes' || doctor.specialty == _selectedSpecialty;
      return matchesQuery && matchesSpecialty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcomingCount = _appointments.where((a) => a.status == AppointmentStatus.upcoming).length;

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
      body: TabBarView(
        controller: _tabController,
        children: [
          // ================= Onglet 1 : Mes Rendez-vous =================
          _buildAppointmentsTab(context),

          // ================= Onglet 2 : Annuaire Médecins & Spécialités =================
          _buildDoctorsTab(context),
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

  Widget _buildAppointmentsTab(BuildContext context) {
    return Column(
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
                selected: _appointmentFilter == null,
                onSelected: (_) => setState(() => _appointmentFilter = null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('À venir'),
                selected: _appointmentFilter == AppointmentStatus.upcoming,
                onSelected: (sel) => setState(() => _appointmentFilter = sel ? AppointmentStatus.upcoming : null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Historique / Passés'),
                selected: _appointmentFilter == AppointmentStatus.completed,
                onSelected: (sel) => setState(() => _appointmentFilter = sel ? AppointmentStatus.completed : null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Annulés'),
                selected: _appointmentFilter == AppointmentStatus.cancelled,
                onSelected: (sel) => setState(() => _appointmentFilter = sel ? AppointmentStatus.cancelled : null),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Liste des rendez-vous
        Expanded(
          child: _filteredAppointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun rendez-vous trouvé',
                        style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: _filteredAppointments.length,
                  itemBuilder: (context, index) {
                    final appointment = _filteredAppointments[index];
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
    );
  }

  Widget _buildDoctorsTab(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 12),
        // Barre de recherche de médecin
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            onChanged: (val) => setState(() => _doctorSearchQuery = val),
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
              final isSelected = _selectedSpecialty == spec.name;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(spec.name),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedSpecialty = spec.name);
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
          child: _filteredDoctors.isEmpty
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
                  itemCount: _filteredDoctors.length,
                  itemBuilder: (context, index) {
                    final doc = _filteredDoctors[index];
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
