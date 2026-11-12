import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/profile_providers.dart';
import '../widgets/lifestyle_card.dart';
import '../widgets/profile_completion_card.dart';
import '../widgets/settings_bottom_sheet.dart';
import '../widgets/vitals_widgets.dart';
import 'medical_records_screen.dart';
import '../../../../i18n/strings.g.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: t.tooltipSettings,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => SettingsBottomSheet.show(context),
        ),
        title: Text(t.profileTitle),
        actions: [
          IconButton(
            tooltip: t.tooltipEditProfile,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.pushNamed('edit-profil'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, label: Text(t.dashboard)),
                  ButtonSegment(value: 1, label: Text(t.medicalRecord)),
                ],
                selected: {_selectedIndex},
                onSelectionChanged: (val) => setState(() => _selectedIndex = val.first),
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _ProfileDashboardView(ref: ref),
          const MedicalRecordsScreen(),
        ],
      ),
    );
  }
}

class _ProfileDashboardView extends StatelessWidget {
  const _ProfileDashboardView({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              Text(t.profileError, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref.invalidate(profileProvider),
                child: Text(t.retry),
              ),
            ],
          ),
        ),
      ),
      data: (profile) => RefreshIndicator(
        onRefresh: () => ref.refresh(profileProvider.future),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileHeader(profile: profile),
            const SizedBox(height: 20),
            ProfileCompletionCard(profile: profile, onComplete: () => context.pushNamed('edit-profil')),
            const SizedBox(height: 20),
            _SectionTitle(t.vitals),
            VitalsGrid(profile: profile),
            const SizedBox(height: 12),
            BmiCard(profile: profile),
            const SizedBox(height: 20),
            _SectionTitle(t.lifestyle),
            LifestyleCard(profile: profile),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(text, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18)),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});
  final UserProfile profile;

  String get _initials {
    final parts = profile.fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Text(
            _initials,
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          profile.fullName.isEmpty ? t.userProfilePlaceholder : profile.fullName,
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(profile.email, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
