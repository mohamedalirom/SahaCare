/// Résultat de l'analyse locale d'urgence médicale
class EmergencyDetectionResult {
  final bool isEmergency;
  final bool isSuicidal;
  final List<String> matchedTriggers;

  const EmergencyDetectionResult({
    required this.isEmergency,
    this.isSuicidal = false,
    this.matchedTriggers = const [],
  });

  static const noEmergency = EmergencyDetectionResult(isEmergency: false);
}

/// Détecteur d'urgence locale instantanée (sans appel LLM)
/// Analyse le texte en français, anglais et arabe de manière insensible à la casse et aux accents.
class EmergencyDetector {
  static const List<String> _suicidalTriggers = [
    // Français
    'envie d en finir',
    'envie de mourir',
    'pensee suicidaire',
    'pensees suicidaires',
    'vouloir me suicider',
    'vouloir en finir',
    'je veux mourir',
    'mettre fin a mes jours',
    'mettre fin a ma vie',
    'idees noires',
    // Anglais
    'suicidal',
    'want to die',
    'kill myself',
    'end my life',
    'commit suicide',
    // Arabe
    'افكار انتحارية',
    'اريد الموت',
    'انتحار',
    'قتل نفسي',
    'انهاء حياتي',
  ];

  static const List<String> _medicalEmergencyTriggers = [
    // Douleur thoracique / Infarctus
    'douleur thoracique',
    'oppression thoracique',
    'douleur poitrine',
    'oppression poitrine',
    'mal a la poitrine',
    'mal au coeur',
    'infarctus',
    'crise cardiaque',
    'arret cardiaque',
    'chest pain',
    'chest pressure',
    'heart attack',
    'cardiac arrest',
    'الم في الصدر',
    'وجع في الصدر',
    'نوبة قلبية',
    'ذبحة صدرية',

    // Détresse respiratoire
    'difficulte a respirer',
    'difficulte pour respirer',
    'impossible de respirer',
    'je n arrive plus a respirer',
    'etouffement',
    'asphyxie',
    'essoufflement severe',
    'manque d air severe',
    'shortness of breath',
    'cannot breathe',
    'difficulty breathing',
    'choking',
    'suffocating',
    'ضيق في التنفس',
    'صعوبة في التنفس',
    'اختناق',

    // Perte de connaissance / Coma
    'perte de connaissance',
    'perdu connaissance',
    'evanouissement',
    'syncope',
    'inconscient',
    'inconsciente',
    'tombe dans les pommes',
    'loss of consciousness',
    'fainted',
    'passed out',
    'unconscious',
    'فقدان الوعي',
    'اغماء',
    'غيبوبة',

    // AVC / Paralysie soudaine
    'paralysie',
    'faiblesse soudaine',
    'bras paralyse',
    'jambe paralysee',
    'visage deforme',
    'bouche deformee',
    'visage paralyse',
    'avc',
    'accident vasculaire',
    'facial drooping',
    'sudden weakness',
    'stroke',
    'شلل',
    'ضعف مفاجئ',
    'جلطة',

    // Élocution soudaine
    'difficulte a parler',
    'trouble de la parole',
    'impossible de parler',
    'parole confuse',
    'slurred speech',
    'cannot speak',
    'difficulty speaking',
    'صعوبة في النطق',
    'صعوبة في الكلام',
    'ثقل في اللسان',

    // Convulsions
    'convulsion',
    'convulsions',
    'crise d epilepsie',
    'crise epileptique',
    'spasmes violents',
    'seizure',
    'seizures',
    'convulsing',
    'تشنج',
    'تشنجات',
    'صرع',

    // Hémorragie importante
    'hemorragie',
    'saignement abondant',
    'saignement ininterrompu',
    'perte de sang importante',
    'crache du sang abondant',
    'vomit du sang',
    'severe bleeding',
    'heavy bleeding',
    'hemorrhage',
    'coughing blood',
    'vomiting blood',
    'نزيف حاد',
    'نزيف شديد',
    'تقيؤ دم',

    // Choc anaphylactique / Allergie sévère
    'reaction allergique severe',
    'gonflement de la gorge',
    'gonflement du visage',
    'oedeme de quincke',
    'choc anaphylactique',
    'anaphylaxie',
    'gorge qui gonfle',
    'anaphylaxis',
    'throat swelling',
    'face swelling',
    'severe allergic',
    'حساسية مفرطة',
    'تورم الحلق',
    'تورم في الحلق',
    'تورم الوجه',

    // Intoxication / Empoisonnement
    'intoxication aigue',
    'empoisonnement',
    'avale du poison',
    'ingere produit chimique',
    'overdose',
    'poisoning',
    'swallowed poison',
    'chemical ingestion',
    'تسمم',
    'تناول سم',
    'جرعة زائدة',

    // Fièvre élevée nourrisson
    'fievre nourrisson',
    'fievre bebe',
    'nourrisson brulant',
    'bebe 40',
    'nourrisson 40',
    'fievre elevee bebe',
    'baby high fever',
    'infant fever',
    'high fever infant',
    'حمى شديدة عند الرضيع',
    'حرارة الرضيع مرتفعة',
  ];

  /// Analyse le texte et retourne un résultat d'urgence
  static EmergencyDetectionResult analyze(String text) {
    if (text.trim().isEmpty) {
      return EmergencyDetectionResult.noEmergency;
    }

    final normalized = _normalize(text);
    final matched = <String>[];
    bool isSuicide = false;

    // 1. Vérification des pensées suicidaires
    for (final trigger in _suicidalTriggers) {
      if (normalized.contains(_normalize(trigger))) {
        matched.add(trigger);
        isSuicide = true;
      }
    }

    if (isSuicide) {
      return EmergencyDetectionResult(
        isEmergency: true,
        isSuicidal: true,
        matchedTriggers: matched,
      );
    }

    // 2. Vérification des urgences médicales vitales
    for (final trigger in _medicalEmergencyTriggers) {
      if (normalized.contains(_normalize(trigger))) {
        matched.add(trigger);
      }
    }

    if (matched.isNotEmpty) {
      return EmergencyDetectionResult(
        isEmergency: true,
        isSuicidal: false,
        matchedTriggers: matched,
      );
    }

    return EmergencyDetectionResult.noEmergency;
  }

  /// Normalise la chaîne : minuscules, suppression des accents, apostrophes et diacritiques arabes
  static String _normalize(String input) {
    var s = input.toLowerCase();

    // Remplacement des accents français/européens
    const withAccents = 'àáâãäåçèéêëìíîïñòóôõöùúûüýÿœæ';
    const withoutAccents = 'aaaaaaceeeeiiiinooooouuuuyyoeae';
    for (int i = 0; i < withAccents.length; i++) {
      s = s.replaceAll(withAccents[i], withoutAccents[i]);
    }

    // Normalisation des apostrophes et tirets
    s = s.replaceAll("'", ' ').replaceAll('’', ' ').replaceAll('-', ' ');

    // Normalisation de l'arabe (suppression des tashkeel et harmonisation des alefs)
    s = s
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '') // tashkeel
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي');

    // Remplacement des espaces multiples
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }
}
