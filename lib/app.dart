import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/phone_frame_wrapper.dart';
import 'core/providers/settings_controller.dart';
import 'i18n/strings.g.dart';

/// Widget racine de l'application SahaCare avec rendu en cadre de Smartphone
class SahaCareApp extends ConsumerWidget {
  const SahaCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final router = ref.watch(routerProvider);

    return TranslationProvider(
      child: Builder(
        builder: (context) {
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settingsState.themeMode,
            locale: TranslationProvider.of(context).flutterLocale,
            supportedLocales: AppLocaleUtils.supportedLocales,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            routerConfig: router,
            builder: (context, child) => PhoneFrameWrapper(
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
