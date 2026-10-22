/// Constantes globales de l'application SahaCare
class AppConstants {
  AppConstants._();

  static const String appName = 'SahaCare';
  static const String appTagline = 'Gestion personnelle de santé';
  static const String appVersion = '1.0.0';
  
  // Configuration API de base (valeur placeholder)
  static const int connectTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;

  // Numéros d'urgence médicale
  static const String emergencyPhone = '190'; // SAMU Tunisie
  static const String emergencyPhoneName = 'SAMU (190)';
  static const String suicidePreventionHelp = 'SAMU (190) ou un proche';
}
