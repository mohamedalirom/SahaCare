/// Constantes et configurations pour l'orientation médicale et l'API Gemini
class OrientationConstants {
  OrientationConstants._();

  /// Modèle Gemini par défaut (modèle Flash rapide et économique)
  static const String defaultGeminiModel = 'gemini-3.5-flash';
  static const String fallbackGeminiModel = 'gemini-3.5-flash-lite';

  /// URL de base de l'API Google Generative Language
  static const String geminiApiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Durée maximale de la requête HTTP
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Longueur minimale et maximale de la description des symptômes
  static const int minSymptomsLength = 10;
  static const int maxSymptomsLength = 500;

  /// Clé SharedPreferences pour le consentement
  static const String consentPrefsKey = 'sahacare_orientation_ai_consent_given';

  /// Délai anti-spam entre deux requêtes (en secondes)
  static const int antiSpamDelaySeconds = 3;

  /// Prompt système d'orientation médicale stricte (sans diagnostic ni médicament)
  static String buildSystemPrompt(List<String> allowedSpecialties) {
    final listStr = allowedSpecialties.join(', ');
    return '''Tu es un assistant d'orientation médicale pour une application de gestion de santé.
Tu ne fais JAMAIS de diagnostic, tu ne proposes JAMAIS de médicament ni de traitement.
À partir de la description de l'utilisateur, tu choisis une ou deux spécialités à consulter, UNIQUEMENT parmi cette liste : [$listStr].
Si la description suggère une urgence vitale, indique urgency = emergency.
Si la description est trop vague, trop courte ou sans rapport avec la santé, indique needs_more_info = true et pose une question de clarification.
Réponds dans la langue de l'utilisateur.
Réponds uniquement avec le JSON demandé.''';
  }

  /// Schéma JSON pour la sortie structurée Gemini
  static Map<String, dynamic> get responseSchema => {
        'type': 'OBJECT',
        'properties': {
          'recommended_specialties': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'name': {'type': 'STRING'},
                'reason': {'type': 'STRING'},
                'confidence': {
                  'type': 'STRING',
                  'enum': ['high', 'medium', 'low']
                }
              },
              'required': ['name', 'reason', 'confidence']
            }
          },
          'urgency': {
            'type': 'STRING',
            'enum': ['routine', 'soon', 'emergency']
          },
          'needs_more_info': {'type': 'BOOLEAN'},
          'clarification_question': {'type': 'STRING'},
          'advice': {'type': 'STRING'}
        },
        'required': [
          'recommended_specialties',
          'urgency',
          'needs_more_info',
          'advice'
        ]
      };

  /// Table locale de secours (mots-clés -> spécialités) pour le mode dégradé hors-ligne
  static const Map<String, List<String>> keywordToSpecialtyMapping = {
    'Dermatologie': [
      'peau',
      'bouton',
      'demangeaison',
      'eruption',
      'acne',
      'eczema',
      'grain de beaute',
      'psoriasis',
      'urticaire',
      'tache'
    ],
    'Dentiste': [
      'dent',
      'dents',
      'gencive',
      'carie',
      'rage de dent',
      'molaire',
      'incisive',
      'appareil dentaire',
      'brossage sang'
    ],
    'Pédiatrie': [
      'enfant',
      'bebe',
      'nourrisson',
      'croissance',
      'vaccin enfant',
      'pediatre',
      'puericulture'
    ],
    'Ophtalmologie': [
      'oeil',
      'yeux',
      'vue',
      'vision',
      'myopie',
      'flou',
      'lentilles',
      'lunettes',
      'conjonctivite',
      'brulure oculaire'
    ],
    'Cardiologie': [
      'coeur',
      'palpitation',
      'pouls',
      'tension',
      'hypertension',
      'souffle au coeur',
      'vaisseaux'
    ],
    'Orthopédie': [
      'os',
      'fracture',
      'entorse',
      'cheville',
      'genou',
      'dos',
      'rachis',
      'scoliose',
      'articulation',
      'ligament'
    ],
    'Neurologie': [
      'migraine',
      'cephalee',
      'maux de tete',
      'tremblement',
      'nerf',
      'sciatique',
      'vertige',
      'amnesie'
    ],
    'Gynécologie': [
      'regles',
      'grossesse',
      'enceinte',
      'uterus',
      'ovaire',
      'menstruation',
      'contraception',
      'cycle'
    ],
    'Psychiatrie': [
      'deprime',
      'depression',
      'anxiete',
      'angoisse',
      'stress',
      'sommeil',
      'insomnie',
      'panique'
    ],
    'ORL': [
      'oreille',
      'gorge',
      'nez',
      'sinusite',
      'acouphene',
      'otite',
      'angine',
      'surdite'
    ],
    'Pneumologie': [
      'poumon',
      'toux',
      'bronchite',
      'asthme',
      'respiration sifflante'
    ],
    'Gastro-entérologie': [
      'estomac',
      'ventre',
      'foie',
      'digestion',
      'reflux',
      'brulure estomac',
      'constipation',
      'diarrhee'
    ],
  };
}
