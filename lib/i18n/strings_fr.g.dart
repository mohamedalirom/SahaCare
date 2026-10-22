///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsFr with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsFr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.fr,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <fr>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key);

	late final TranslationsFr _root = this; // ignore: unused_field

	@override 
	TranslationsFr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsFr(meta: meta ?? this.$meta);

	// Translations
	@override String get settings => 'Paramètres';
	@override String get accountSecurity => 'Compte & Sécurité';
	@override String get biometrics => 'Biométrie (FaceID / Empreinte)';
	@override String get changePassword => 'Changer le mot de passe';
	@override String get passwordResetSent => 'Un lien de réinitialisation a été envoyé à votre adresse e-mail.';
	@override String passwordResetError({required Object error}) => 'Erreur lors de l\'envoi du lien : ${error}';
	@override String get passwordResetNoEmail => 'Aucune adresse e-mail associée à ce compte.';
	@override String get biometricsEnabled => 'Authentification biométrique activée.';
	@override String get biometricsDisabled => 'Authentification biométrique désactivée.';
	@override String get biometricsNotSupported => 'La biométrie n\'est pas disponible sur cet appareil.';
	@override String get biometricsAuthFailed => 'Échec ou annulation de l\'authentification biométrique.';
	@override String get biometricsPromptReason => 'Confirmez votre identité pour activer le verrouillage biométrique.';
	@override String get logout => 'Déconnexion';
	@override String get deleteAccount => 'Supprimer le compte';
	@override String get appPreferences => 'Préférences de l\'Application';
	@override String get theme => 'Thème';
	@override String get themeLight => 'Clair';
	@override String get themeDark => 'Sombre';
	@override String get themeSystem => 'Système';
	@override String get language => 'Langue';
	@override String get langFrench => 'Français';
	@override String get langArabic => 'Arabe';
	@override String get langEnglish => 'Anglais';
	@override String get metricSystem => 'Système Métrique (kg, cm)';
	@override String get metricSubtitle => 'Désactiver pour l\'impérial (lbs, in)';
	@override String get privacyMedical => 'Confidentialité & Données Médicales';
	@override String get profileVisibility => 'Visibilité du Profil';
	@override String get profileVisibilitySub => 'Autoriser les médecins à consulter mon dossier';
	@override String get exportRecord => 'Exporter mon Dossier (PDF/CSV)';
	@override String get about => 'À Propos';
	@override String get termsPrivacy => 'Conditions & Politique de confidentialité';
	@override String get appVersion => 'Version de l\'application';
	@override String get navProfile => 'Profil';
	@override String get navMedications => 'Médicaments';
	@override String get navAppointments => 'Rendez-vous';
	@override String get navTracking => 'Suivi';
	@override String get navDocuments => 'Documents';
	@override String get profileTitle => 'Mon Profil';
	@override String get dashboard => 'Tableau de bord';
	@override String get medicalRecord => 'Dossier Médical';
	@override String get profileError => 'Impossible de charger le profil.';
	@override String get retry => 'Réessayer';
	@override String get vitals => 'Signes vitaux';
	@override String get lifestyle => 'Mode de vie';
	@override String get tooltipSettings => 'Paramètres';
	@override String get tooltipEditProfile => 'Modifier le profil';
	@override String get userProfilePlaceholder => 'Utilisateur';
	@override String get height => 'Taille';
	@override String get weight => 'Poids';
	@override String get bmi => 'Indice de masse corporelle';
	@override String get bmiUnderweight => 'Insuffisance pondérale';
	@override String get bmiNormal => 'Poids normal';
	@override String get bmiOverweight => 'Surpoids';
	@override String get bmiObesity => 'Obésité';
	@override String get birthDate => 'Date de naissance';
	@override String get biologicalSex => 'Sexe biologique';
	@override String get tobacco => 'Tabac';
	@override String get alcohol => 'Alcool';
	@override String get occasional => 'Occasionnel';
	@override String get diseases => 'Maladies';
	@override String get allergies => 'Allergies';
	@override String get history => 'Antécédents';
	@override String get chronic => 'Chronique';
	@override String get acute => 'Aiguë';
	@override String get last12Months => '12 derniers mois';
	@override String get last5Years => '5 dernières années';
	@override String get older => 'Plus ancien';
	@override String get reset => 'Réinitialiser';
	@override String get bloodGroup => 'Groupe sanguin';
	@override String get age => 'Âge';
	@override String get yearsOld => 'ans';
	@override String get bmiPrompt => 'Renseignez votre taille et votre poids\npour calculer votre IMC.';
	@override String get personalInfo => 'Informations personnelles';
	@override String get fullName => 'Nom complet';
	@override String get physiologicalData => 'Données physiologiques';
	@override String get rhesus => 'Rhésus';
	@override String get physicalActivity => 'Activité physique';
	@override String get saveChanges => 'Enregistrer les modifications';
	@override String get notSpecified => 'Non renseigné';
	@override String get profileCompletion => 'Complétion du profil';
	@override String get profileComplete => 'Profil complet 🎉';
	@override String get allInfoProvided => 'Toutes vos informations sont renseignées.';
	@override String get toComplete => 'À compléter : ';
	@override String get completeMyProfile => 'Compléter mon profil';
	@override late final _Translations$biologicalSexOptions$fr biologicalSexOptions = _Translations$biologicalSexOptions$fr._(_root);
	@override late final _Translations$rhesusOptions$fr rhesusOptions = _Translations$rhesusOptions$fr._(_root);
	@override late final _Translations$smokingStatus$fr smokingStatus = _Translations$smokingStatus$fr._(_root);
	@override late final _Translations$alcoholConsumption$fr alcoholConsumption = _Translations$alcoholConsumption$fr._(_root);
	@override late final _Translations$physicalActivityOptions$fr physicalActivityOptions = _Translations$physicalActivityOptions$fr._(_root);
	@override String get addCondition => 'Ajouter une Maladie';
	@override String get addDisease => 'Ajouter une Maladie';
	@override String get addAllergy => 'Ajouter une Allergie';
	@override String get addHistory => 'Ajouter un Antécédent';
	@override String get addAntecedent => 'Ajouter un Antécédent';
	@override String get add => 'Ajouter';
	@override String get addHistoryTitle => 'Ajouter — Antécédent';
	@override String get historyTitle => 'Titre de l\'antécédent';
	@override String get descriptionOptional => 'Description (optionnel)';
	@override String get addAllergyTitle => 'Ajouter — Allergie';
	@override String get allergen => 'Allergène';
	@override String get severity => 'Sévérité';
	@override String get category => 'Catégorie';
	@override late final _Translations$allergySeverityOptions$fr allergySeverityOptions = _Translations$allergySeverityOptions$fr._(_root);
	@override late final _Translations$allergyKindOptions$fr allergyKindOptions = _Translations$allergyKindOptions$fr._(_root);
	@override String get addDiseaseTitle => 'Ajouter — Maladie';
	@override String get diseaseName => 'Nom de la maladie';
	@override String get diagnosisDate => 'Date du diagnostic';
	@override String get eventDate => 'Date de l\'événement';
	@override String get chronicDisease => 'Maladie chronique';
	@override String get editHistoryTitle => 'Modifier — Antécédent';
	@override String get editAllergyTitle => 'Modifier — Allergie';
	@override String get editDiseaseTitle => 'Modifier — Maladie';
	@override String get requiredField => 'Ce champ est obligatoire';
	@override String get minCharacters => 'Au moins 2 caractères';
	@override String get maxCharacters => '80 caractères maximum';
	@override String get selectDate => 'Sélectionner une date';
	@override String get clearDate => 'Effacer la date';
	@override String get date => 'Date';
	@override String get saveFailed => 'Enregistrement impossible. Veuillez réessayer.';
	@override String diagnosedIn({required Object date}) => 'Diagnostiquée en ${date}';
	@override String get unknownDate => 'Date inconnue';
	@override String get nearbyTitle => 'Médecins et cliniques à proximité';
	@override String get nearbySearchHint => 'Rechercher médecin, clinique, spécialité...';
	@override String get nearbyRadius => 'Rayon';
	@override String nearbySaved({required Object name}) => '${name} a été enregistré dans votre carnet !';
	@override String nearbyAlreadySaved({required Object name}) => '${name} existe déjà dans votre carnet.';
	@override String get nearbyBookAppointment => 'Prendre RDV';
	@override String get nearbyOsmAttribution => '© Contributeurs d\'OpenStreetMap';
	@override String get nearbyOsmWarning => 'Données OpenStreetMap : vérifiez les informations auprès de l\'établissement.';
	@override String get orientationTitle => 'Orientation Médicale';
	@override String get orientationSubtitle => 'Quelle spécialité consulter ?';
	@override String get orientationDisclaimer => 'Cette suggestion est une orientation générale, pas un diagnostic. Elle ne remplace pas l\'avis d\'un médecin. En cas d\'urgence, appelez le 190.';
	@override String get orientationFindSpecialty => 'Trouver la bonne spécialité';
	@override String get orientationSymptomsHint => 'Décrivez ce que vous ressentez (douleur, localisation, durée)...';
	@override String get orientationAnalyzing => 'Analyse en cours...';
	@override String get orientationEmergencyAlert => 'Attention : Urgence médicale potentielle';
	@override String get orientationEmergencyCall => 'Appeler le SAMU (190)';
	@override String get orientationHistory => 'Historique des orientations';
	@override String get orientationNoHistory => 'Aucun historique enregistré';
	@override String get orientationClearHistory => 'Tout effacer';
}

// Path: biologicalSexOptions
class _Translations$biologicalSexOptions$fr implements Translations$biologicalSexOptions$en {
	_Translations$biologicalSexOptions$fr._(this._root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get male => 'Homme';
	@override String get female => 'Femme';
	@override String get other => 'Autre';
}

// Path: rhesusOptions
class _Translations$rhesusOptions$fr implements Translations$rhesusOptions$en {
	_Translations$rhesusOptions$fr._(this._root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get positive => 'Positif (+)';
	@override String get negative => 'Négatif (−)';
}

// Path: smokingStatus
class _Translations$smokingStatus$fr implements Translations$smokingStatus$en {
	_Translations$smokingStatus$fr._(this._root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get never => 'Non-fumeur';
	@override String get former => 'Ancien fumeur';
	@override String get occasional => 'Occasionnel';
	@override String get regular => 'Régulier';
}

// Path: alcoholConsumption
class _Translations$alcoholConsumption$fr implements Translations$alcoholConsumption$en {
	_Translations$alcoholConsumption$fr._(this._root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get none => 'Jamais';
	@override String get occasional => 'Occasionnelle';
	@override String get moderate => 'Modérée';
	@override String get frequent => 'Fréquente';
}

// Path: physicalActivityOptions
class _Translations$physicalActivityOptions$fr implements Translations$physicalActivityOptions$en {
	_Translations$physicalActivityOptions$fr._(this._root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get sedentary => 'Sédentaire';
	@override String get light => 'Légère';
	@override String get moderate => 'Modérée';
	@override String get intense => 'Intense';
}

// Path: allergySeverityOptions
class _Translations$allergySeverityOptions$fr implements Translations$allergySeverityOptions$en {
	_Translations$allergySeverityOptions$fr._(this._root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get mild => 'Légère';
	@override String get moderate => 'Modérée';
	@override String get severe => 'Sévère';
}

// Path: allergyKindOptions
class _Translations$allergyKindOptions$fr implements Translations$allergyKindOptions$en {
	_Translations$allergyKindOptions$fr._(this._root);

	final TranslationsFr _root; // ignore: unused_field

	// Translations
	@override String get medication => 'Médicament';
	@override String get food => 'Alimentaire';
	@override String get other => 'Autre';
}

/// The flat map containing all translations for locale <fr>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsFr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'settings' => 'Paramètres',
			'accountSecurity' => 'Compte & Sécurité',
			'biometrics' => 'Biométrie (FaceID / Empreinte)',
			'changePassword' => 'Changer le mot de passe',
			'passwordResetSent' => 'Un lien de réinitialisation a été envoyé à votre adresse e-mail.',
			'passwordResetError' => ({required Object error}) => 'Erreur lors de l\'envoi du lien : ${error}',
			'passwordResetNoEmail' => 'Aucune adresse e-mail associée à ce compte.',
			'biometricsEnabled' => 'Authentification biométrique activée.',
			'biometricsDisabled' => 'Authentification biométrique désactivée.',
			'biometricsNotSupported' => 'La biométrie n\'est pas disponible sur cet appareil.',
			'biometricsAuthFailed' => 'Échec ou annulation de l\'authentification biométrique.',
			'biometricsPromptReason' => 'Confirmez votre identité pour activer le verrouillage biométrique.',
			'logout' => 'Déconnexion',
			'deleteAccount' => 'Supprimer le compte',
			'appPreferences' => 'Préférences de l\'Application',
			'theme' => 'Thème',
			'themeLight' => 'Clair',
			'themeDark' => 'Sombre',
			'themeSystem' => 'Système',
			'language' => 'Langue',
			'langFrench' => 'Français',
			'langArabic' => 'Arabe',
			'langEnglish' => 'Anglais',
			'metricSystem' => 'Système Métrique (kg, cm)',
			'metricSubtitle' => 'Désactiver pour l\'impérial (lbs, in)',
			'privacyMedical' => 'Confidentialité & Données Médicales',
			'profileVisibility' => 'Visibilité du Profil',
			'profileVisibilitySub' => 'Autoriser les médecins à consulter mon dossier',
			'exportRecord' => 'Exporter mon Dossier (PDF/CSV)',
			'about' => 'À Propos',
			'termsPrivacy' => 'Conditions & Politique de confidentialité',
			'appVersion' => 'Version de l\'application',
			'navProfile' => 'Profil',
			'navMedications' => 'Médicaments',
			'navAppointments' => 'Rendez-vous',
			'navTracking' => 'Suivi',
			'navDocuments' => 'Documents',
			'profileTitle' => 'Mon Profil',
			'dashboard' => 'Tableau de bord',
			'medicalRecord' => 'Dossier Médical',
			'profileError' => 'Impossible de charger le profil.',
			'retry' => 'Réessayer',
			'vitals' => 'Signes vitaux',
			'lifestyle' => 'Mode de vie',
			'tooltipSettings' => 'Paramètres',
			'tooltipEditProfile' => 'Modifier le profil',
			'userProfilePlaceholder' => 'Utilisateur',
			'height' => 'Taille',
			'weight' => 'Poids',
			'bmi' => 'Indice de masse corporelle',
			'bmiUnderweight' => 'Insuffisance pondérale',
			'bmiNormal' => 'Poids normal',
			'bmiOverweight' => 'Surpoids',
			'bmiObesity' => 'Obésité',
			'birthDate' => 'Date de naissance',
			'biologicalSex' => 'Sexe biologique',
			'tobacco' => 'Tabac',
			'alcohol' => 'Alcool',
			'occasional' => 'Occasionnel',
			'diseases' => 'Maladies',
			'allergies' => 'Allergies',
			'history' => 'Antécédents',
			'chronic' => 'Chronique',
			'acute' => 'Aiguë',
			'last12Months' => '12 derniers mois',
			'last5Years' => '5 dernières années',
			'older' => 'Plus ancien',
			'reset' => 'Réinitialiser',
			'bloodGroup' => 'Groupe sanguin',
			'age' => 'Âge',
			'yearsOld' => 'ans',
			'bmiPrompt' => 'Renseignez votre taille et votre poids\npour calculer votre IMC.',
			'personalInfo' => 'Informations personnelles',
			'fullName' => 'Nom complet',
			'physiologicalData' => 'Données physiologiques',
			'rhesus' => 'Rhésus',
			'physicalActivity' => 'Activité physique',
			'saveChanges' => 'Enregistrer les modifications',
			'notSpecified' => 'Non renseigné',
			'profileCompletion' => 'Complétion du profil',
			'profileComplete' => 'Profil complet 🎉',
			'allInfoProvided' => 'Toutes vos informations sont renseignées.',
			'toComplete' => 'À compléter : ',
			'completeMyProfile' => 'Compléter mon profil',
			'biologicalSexOptions.male' => 'Homme',
			'biologicalSexOptions.female' => 'Femme',
			'biologicalSexOptions.other' => 'Autre',
			'rhesusOptions.positive' => 'Positif (+)',
			'rhesusOptions.negative' => 'Négatif (−)',
			'smokingStatus.never' => 'Non-fumeur',
			'smokingStatus.former' => 'Ancien fumeur',
			'smokingStatus.occasional' => 'Occasionnel',
			'smokingStatus.regular' => 'Régulier',
			'alcoholConsumption.none' => 'Jamais',
			'alcoholConsumption.occasional' => 'Occasionnelle',
			'alcoholConsumption.moderate' => 'Modérée',
			'alcoholConsumption.frequent' => 'Fréquente',
			'physicalActivityOptions.sedentary' => 'Sédentaire',
			'physicalActivityOptions.light' => 'Légère',
			'physicalActivityOptions.moderate' => 'Modérée',
			'physicalActivityOptions.intense' => 'Intense',
			'addCondition' => 'Ajouter une Maladie',
			'addDisease' => 'Ajouter une Maladie',
			'addAllergy' => 'Ajouter une Allergie',
			'addHistory' => 'Ajouter un Antécédent',
			'addAntecedent' => 'Ajouter un Antécédent',
			'add' => 'Ajouter',
			'addHistoryTitle' => 'Ajouter — Antécédent',
			'historyTitle' => 'Titre de l\'antécédent',
			'descriptionOptional' => 'Description (optionnel)',
			'addAllergyTitle' => 'Ajouter — Allergie',
			'allergen' => 'Allergène',
			'severity' => 'Sévérité',
			'category' => 'Catégorie',
			'allergySeverityOptions.mild' => 'Légère',
			'allergySeverityOptions.moderate' => 'Modérée',
			'allergySeverityOptions.severe' => 'Sévère',
			'allergyKindOptions.medication' => 'Médicament',
			'allergyKindOptions.food' => 'Alimentaire',
			'allergyKindOptions.other' => 'Autre',
			'addDiseaseTitle' => 'Ajouter — Maladie',
			'diseaseName' => 'Nom de la maladie',
			'diagnosisDate' => 'Date du diagnostic',
			'eventDate' => 'Date de l\'événement',
			'chronicDisease' => 'Maladie chronique',
			'editHistoryTitle' => 'Modifier — Antécédent',
			'editAllergyTitle' => 'Modifier — Allergie',
			'editDiseaseTitle' => 'Modifier — Maladie',
			'requiredField' => 'Ce champ est obligatoire',
			'minCharacters' => 'Au moins 2 caractères',
			'maxCharacters' => '80 caractères maximum',
			'selectDate' => 'Sélectionner une date',
			'clearDate' => 'Effacer la date',
			'date' => 'Date',
			'saveFailed' => 'Enregistrement impossible. Veuillez réessayer.',
			'diagnosedIn' => ({required Object date}) => 'Diagnostiquée en ${date}',
			'unknownDate' => 'Date inconnue',
			'nearbyTitle' => 'Médecins et cliniques à proximité',
			'nearbySearchHint' => 'Rechercher médecin, clinique, spécialité...',
			'nearbyRadius' => 'Rayon',
			'nearbySaved' => ({required Object name}) => '${name} a été enregistré dans votre carnet !',
			'nearbyAlreadySaved' => ({required Object name}) => '${name} existe déjà dans votre carnet.',
			'nearbyBookAppointment' => 'Prendre RDV',
			'nearbyOsmAttribution' => '© Contributeurs d\'OpenStreetMap',
			'nearbyOsmWarning' => 'Données OpenStreetMap : vérifiez les informations auprès de l\'établissement.',
			'orientationTitle' => 'Orientation Médicale',
			'orientationSubtitle' => 'Quelle spécialité consulter ?',
			'orientationDisclaimer' => 'Cette suggestion est une orientation générale, pas un diagnostic. Elle ne remplace pas l\'avis d\'un médecin. En cas d\'urgence, appelez le 190.',
			'orientationFindSpecialty' => 'Trouver la bonne spécialité',
			'orientationSymptomsHint' => 'Décrivez ce que vous ressentez (douleur, localisation, durée)...',
			'orientationAnalyzing' => 'Analyse en cours...',
			'orientationEmergencyAlert' => 'Attention : Urgence médicale potentielle',
			'orientationEmergencyCall' => 'Appeler le SAMU (190)',
			'orientationHistory' => 'Historique des orientations',
			'orientationNoHistory' => 'Aucun historique enregistré',
			'orientationClearHistory' => 'Tout effacer',
			_ => null,
		};
	}
}
