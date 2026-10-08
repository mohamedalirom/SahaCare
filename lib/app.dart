import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/phone_frame_wrapper.dart';

/// Widget racine de l'application SahaCare avec rendu en cadre de Smartphone
class SahaCareApp extends ConsumerWidget {
  const SahaCareApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
      builder: (context, child) => PhoneFrameWrapper(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
