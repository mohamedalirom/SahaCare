import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahacare/app.dart';
import 'package:sahacare/core/routes/app_router.dart';
import 'package:sahacare/features/auth/services/auth_service.dart';
import 'package:sahacare/features/profil/domain/entities/medical_history.dart';
import 'package:sahacare/features/profil/domain/entities/user_profile.dart';
import 'package:sahacare/features/profil/presentation/providers/profile_providers.dart';
import 'package:sahacare/features/profil/presentation/screens/medical_records_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserProfile', () {
    test('calcule l\'IMC et sa catégorie', () {
      const p = UserProfile(id: 'u', heightCm: 180, weightKg: 81);
      expect(p.bmi, closeTo(25.0, 0.05));
      expect(p.bmiCategory, BmiCategory.overweight);

      expect(const UserProfile(id: 'u', heightCm: 180, weightKg: 70).bmiCategory, BmiCategory.normal);
      expect(const UserProfile(id: 'u', heightCm: 180, weightKg: 55).bmiCategory, BmiCategory.underweight);
      expect(const UserProfile(id: 'u', heightCm: 170, weightKg: 100).bmiCategory, BmiCategory.obese);
      expect(const UserProfile(id: 'u').bmi, isNull);
    });

    test('calcule le pourcentage de complétion', () {
      expect(const UserProfile(id: 'u').completion, 0);

      final full = UserProfile(
        id: 'u',
        fullName: 'Youssef',
        dateOfBirth: DateTime(1999, 1, 1),
        sex: BiologicalSex.male,
        bloodGroup: 'O',
        rhesus: '+',
        heightCm: 180,
        weightKg: 75,
        smoking: SmokingStatus.never,
        alcohol: AlcoholConsumption.none,
        activity: PhysicalActivity.moderate,
      );
      expect(full.completion, 1);

      // Groupe sanguin incomplet (sans rhésus) => non compté
      expect(const UserProfile(id: 'u', bloodGroup: 'A').completion, 0);
      const partial = UserProfile(id: 'u', fullName: 'Y', bloodGroup: 'A', rhesus: '-');
      expect(partial.completion, closeTo(2 / 9, 0.001));
    });

    test('sérialise vers / depuis Supabase', () {
      final p = UserProfile(
        id: 'u',
        fullName: ' Youssef ',
        dateOfBirth: DateTime(1999, 3, 7),
        sex: BiologicalSex.female,
        smoking: SmokingStatus.former,
      );
      final map = p.toMap();
      expect(map['full_name'], 'Youssef');
      expect(map['date_of_birth'], '1999-03-07');
      expect(map['biological_sex'], 'female');

      final back = UserProfile.fromMap(map);
      expect(back.sex, BiologicalSex.female);
      expect(back.smoking, SmokingStatus.former);
      expect(back.dateOfBirth, DateTime(1999, 3, 7));
    });
  });

  group('Dossier médical CRUD', () {
    final history = MedicalHistory(
      diseases: [Disease(id: '1', name: 'Hypertension', diagnosedAt: DateTime(2021, 3), isChronic: true)],
      allergies: const [Allergy(id: '1', name: 'Pénicilline', severity: AllergySeverity.severe)],
      history: [MedicalHistoryEntry(id: '1', title: 'Appendicectomie', date: DateTime(2015, 5))],
    );

    testWidgets('affiche les données et expose les actions de mutation', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [medicalHistoryProvider.overrideWith(() => _FakeMedicalNotifier(history))],
          child: const MaterialApp(home: Scaffold(body: MedicalRecordsScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hypertension'), findsOneWidget);
      await tester.tap(find.text('Allergies'));
      await tester.pumpAndSettle();
      expect(find.text('Pénicilline'), findsOneWidget);
      await tester.tap(find.text('Antécédents'));
      await tester.pumpAndSettle();
      expect(find.text('Appendicectomie'), findsOneWidget);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byType(Dismissible), findsOneWidget);
      expect(find.byType(FilterChip), findsWidgets);
    });
  });

  group('Déconnexion', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('confirmation puis redirection vers /login', (tester) async {
      tester.view.physicalSize = const Size(412 * 3, 1800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      addTearDown(() async => AuthService.instance.signOut());

      await AuthService.instance.signInWithPassword(email: 'y@sahacare.tn', password: 'secret');
      appRouter.go('/profil');
      await tester.pumpWidget(const ProviderScope(child: SahaCareApp()));
      await tester.pumpAndSettle();

      expect(find.text('Mon Profil'), findsOneWidget);
      expect(find.textContaining('Complétion du profil'), findsOneWidget);

      // Annuler : on reste sur le profil, session conservée
      await tester.scrollUntilVisible(
        find.byKey(const Key('logout_button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      expect(find.text('Se déconnecter ?'), findsOneWidget);
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Mon Profil'), findsOneWidget);
      expect(AuthService.instance.isAuthenticated, isTrue);

      // Confirmer : session effacée + écran de connexion
      await tester.tap(find.byKey(const Key('logout_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Se déconnecter').last);
      await tester.pumpAndSettle();

      expect(AuthService.instance.isAuthenticated, isFalse);
      expect(find.text('Bienvenue sur SahaCare'), findsOneWidget);
    });

    testWidgets('une route profil sans session redirige vers /login', (tester) async {
      await AuthService.instance.signOut();
      appRouter.go('/profil');
      await tester.pumpWidget(const ProviderScope(child: SahaCareApp()));
      await tester.pumpAndSettle();
      expect(find.text('Bienvenue sur SahaCare'), findsOneWidget);
    });
  });
}

class _FakeMedicalNotifier extends MedicalHistoryNotifier {
  _FakeMedicalNotifier(this._data);
  final MedicalHistory _data;

  @override
  Future<MedicalHistory> build() async => _data;
}
