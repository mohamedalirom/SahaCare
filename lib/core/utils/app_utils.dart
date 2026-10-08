import 'package:intl/intl.dart';

/// Fonctions utilitaires réutilisables dans toute l'application
class AppUtils {
  AppUtils._();

  /// Formate une date au format français standard (ex: 08/10/2026)
  static String formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Formate une date et une heure (ex: 08/10/2026 14:30)
  static String formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }
}
