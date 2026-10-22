///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsEn = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations

	/// en: 'Settings'
	String get settings => 'Settings';

	/// en: 'Account & Security'
	String get accountSecurity => 'Account & Security';

	/// en: 'Biometrics (FaceID / Fingerprint)'
	String get biometrics => 'Biometrics (FaceID / Fingerprint)';

	/// en: 'Change Password'
	String get changePassword => 'Change Password';

	/// en: 'A password reset link has been sent to your email.'
	String get passwordResetSent => 'A password reset link has been sent to your email.';

	/// en: 'Error sending reset link: ${error}'
	String passwordResetError({required Object error}) => 'Error sending reset link: ${error}';

	/// en: 'No email associated with this account.'
	String get passwordResetNoEmail => 'No email associated with this account.';

	/// en: 'Biometric authentication enabled.'
	String get biometricsEnabled => 'Biometric authentication enabled.';

	/// en: 'Biometric authentication disabled.'
	String get biometricsDisabled => 'Biometric authentication disabled.';

	/// en: 'Biometrics not supported on this device.'
	String get biometricsNotSupported => 'Biometrics not supported on this device.';

	/// en: 'Biometric authentication failed or cancelled.'
	String get biometricsAuthFailed => 'Biometric authentication failed or cancelled.';

	/// en: 'Confirm your identity to enable biometric authentication.'
	String get biometricsPromptReason => 'Confirm your identity to enable biometric authentication.';

	/// en: 'Logout'
	String get logout => 'Logout';

	/// en: 'Delete Account'
	String get deleteAccount => 'Delete Account';

	/// en: 'App Preferences'
	String get appPreferences => 'App Preferences';

	/// en: 'Theme'
	String get theme => 'Theme';

	/// en: 'Light'
	String get themeLight => 'Light';

	/// en: 'Dark'
	String get themeDark => 'Dark';

	/// en: 'System'
	String get themeSystem => 'System';

	/// en: 'Language'
	String get language => 'Language';

	/// en: 'French'
	String get langFrench => 'French';

	/// en: 'Arabic'
	String get langArabic => 'Arabic';

	/// en: 'English'
	String get langEnglish => 'English';

	/// en: 'Metric System (kg, cm)'
	String get metricSystem => 'Metric System (kg, cm)';

	/// en: 'Disable for imperial (lbs, in)'
	String get metricSubtitle => 'Disable for imperial (lbs, in)';

	/// en: 'Privacy & Medical Data'
	String get privacyMedical => 'Privacy & Medical Data';

	/// en: 'Profile Visibility'
	String get profileVisibility => 'Profile Visibility';

	/// en: 'Allow doctors to view my record'
	String get profileVisibilitySub => 'Allow doctors to view my record';

	/// en: 'Export Record (PDF/CSV)'
	String get exportRecord => 'Export Record (PDF/CSV)';

	/// en: 'About'
	String get about => 'About';

	/// en: 'Terms & Privacy Policy'
	String get termsPrivacy => 'Terms & Privacy Policy';

	/// en: 'App Version'
	String get appVersion => 'App Version';

	/// en: 'Profile'
	String get navProfile => 'Profile';

	/// en: 'Medications'
	String get navMedications => 'Medications';

	/// en: 'Appointments'
	String get navAppointments => 'Appointments';

	/// en: 'Tracking'
	String get navTracking => 'Tracking';

	/// en: 'Documents'
	String get navDocuments => 'Documents';

	/// en: 'Profile'
	String get profileTitle => 'Profile';

	/// en: 'Dashboard'
	String get dashboard => 'Dashboard';

	/// en: 'Medical Record'
	String get medicalRecord => 'Medical Record';

	/// en: 'Failed to load profile.'
	String get profileError => 'Failed to load profile.';

	/// en: 'Retry'
	String get retry => 'Retry';

	/// en: 'Vitals'
	String get vitals => 'Vitals';

	/// en: 'Lifestyle'
	String get lifestyle => 'Lifestyle';

	/// en: 'Settings'
	String get tooltipSettings => 'Settings';

	/// en: 'Edit Profile'
	String get tooltipEditProfile => 'Edit Profile';

	/// en: 'User'
	String get userProfilePlaceholder => 'User';

	/// en: 'Height'
	String get height => 'Height';

	/// en: 'Weight'
	String get weight => 'Weight';

	/// en: 'Body Mass Index'
	String get bmi => 'Body Mass Index';

	/// en: 'Underweight'
	String get bmiUnderweight => 'Underweight';

	/// en: 'Normal weight'
	String get bmiNormal => 'Normal weight';

	/// en: 'Overweight'
	String get bmiOverweight => 'Overweight';

	/// en: 'Obesity'
	String get bmiObesity => 'Obesity';

	/// en: 'Date of Birth'
	String get birthDate => 'Date of Birth';

	/// en: 'Biological Sex'
	String get biologicalSex => 'Biological Sex';

	/// en: 'Tobacco'
	String get tobacco => 'Tobacco';

	/// en: 'Alcohol'
	String get alcohol => 'Alcohol';

	/// en: 'Occasional'
	String get occasional => 'Occasional';

	/// en: 'Diseases'
	String get diseases => 'Diseases';

	/// en: 'Allergies'
	String get allergies => 'Allergies';

	/// en: 'History'
	String get history => 'History';

	/// en: 'Chronic'
	String get chronic => 'Chronic';

	/// en: 'Acute'
	String get acute => 'Acute';

	/// en: 'Last 12 months'
	String get last12Months => 'Last 12 months';

	/// en: 'Last 5 years'
	String get last5Years => 'Last 5 years';

	/// en: 'Older'
	String get older => 'Older';

	/// en: 'Reset'
	String get reset => 'Reset';

	/// en: 'Blood type'
	String get bloodGroup => 'Blood type';

	/// en: 'Age'
	String get age => 'Age';

	/// en: 'years'
	String get yearsOld => 'years';

	/// en: 'Enter your height and weight to calculate your BMI.'
	String get bmiPrompt => 'Enter your height and weight\nto calculate your BMI.';

	/// en: 'Personal Information'
	String get personalInfo => 'Personal Information';

	/// en: 'Full Name'
	String get fullName => 'Full Name';

	/// en: 'Physiological Data'
	String get physiologicalData => 'Physiological Data';

	/// en: 'Rhesus'
	String get rhesus => 'Rhesus';

	/// en: 'Physical Activity'
	String get physicalActivity => 'Physical Activity';

	/// en: 'Save Changes'
	String get saveChanges => 'Save Changes';

	/// en: 'Not specified'
	String get notSpecified => 'Not specified';

	/// en: 'Profile completion'
	String get profileCompletion => 'Profile completion';

	/// en: 'Profile complete 🎉'
	String get profileComplete => 'Profile complete 🎉';

	/// en: 'All your information is provided.'
	String get allInfoProvided => 'All your information is provided.';

	/// en: 'To complete: '
	String get toComplete => 'To complete: ';

	/// en: 'Complete my profile'
	String get completeMyProfile => 'Complete my profile';

	late final Translations$biologicalSexOptions$en biologicalSexOptions = Translations$biologicalSexOptions$en._(_root);
	late final Translations$rhesusOptions$en rhesusOptions = Translations$rhesusOptions$en._(_root);
	late final Translations$smokingStatus$en smokingStatus = Translations$smokingStatus$en._(_root);
	late final Translations$alcoholConsumption$en alcoholConsumption = Translations$alcoholConsumption$en._(_root);
	late final Translations$physicalActivityOptions$en physicalActivityOptions = Translations$physicalActivityOptions$en._(_root);

	/// en: 'Add Disease'
	String get addCondition => 'Add Disease';

	/// en: 'Add Disease'
	String get addDisease => 'Add Disease';

	/// en: 'Add Allergy'
	String get addAllergy => 'Add Allergy';

	/// en: 'Add Medical History'
	String get addHistory => 'Add Medical History';

	/// en: 'Add Medical History'
	String get addAntecedent => 'Add Medical History';

	/// en: 'Add'
	String get add => 'Add';

	/// en: 'Add — Medical History'
	String get addHistoryTitle => 'Add — Medical History';

	/// en: 'History title'
	String get historyTitle => 'History title';

	/// en: 'Description (optional)'
	String get descriptionOptional => 'Description (optional)';

	/// en: 'Add — Allergy'
	String get addAllergyTitle => 'Add — Allergy';

	/// en: 'Allergen'
	String get allergen => 'Allergen';

	/// en: 'Severity'
	String get severity => 'Severity';

	/// en: 'Category'
	String get category => 'Category';

	late final Translations$allergySeverityOptions$en allergySeverityOptions = Translations$allergySeverityOptions$en._(_root);
	late final Translations$allergyKindOptions$en allergyKindOptions = Translations$allergyKindOptions$en._(_root);

	/// en: 'Add — Disease'
	String get addDiseaseTitle => 'Add — Disease';

	/// en: 'Disease name'
	String get diseaseName => 'Disease name';

	/// en: 'Diagnosis date'
	String get diagnosisDate => 'Diagnosis date';

	/// en: 'Event date'
	String get eventDate => 'Event date';

	/// en: 'Chronic condition'
	String get chronicDisease => 'Chronic condition';

	/// en: 'Edit — Medical History'
	String get editHistoryTitle => 'Edit — Medical History';

	/// en: 'Edit — Allergy'
	String get editAllergyTitle => 'Edit — Allergy';

	/// en: 'Edit — Disease'
	String get editDiseaseTitle => 'Edit — Disease';

	/// en: 'This field is required'
	String get requiredField => 'This field is required';

	/// en: 'At least 2 characters'
	String get minCharacters => 'At least 2 characters';

	/// en: '80 characters maximum'
	String get maxCharacters => '80 characters maximum';

	/// en: 'Select a date'
	String get selectDate => 'Select a date';

	/// en: 'Clear date'
	String get clearDate => 'Clear date';

	/// en: 'Date'
	String get date => 'Date';

	/// en: 'Unable to save. Please try again.'
	String get saveFailed => 'Unable to save. Please try again.';

	/// en: 'Diagnosed in ${date}'
	String diagnosedIn({required Object date}) => 'Diagnosed in ${date}';

	/// en: 'Unknown date'
	String get unknownDate => 'Unknown date';

	/// en: 'Nearby Doctors & Clinics'
	String get nearbyTitle => 'Nearby Doctors & Clinics';

	/// en: 'Search doctor, clinic, specialty...'
	String get nearbySearchHint => 'Search doctor, clinic, specialty...';

	/// en: 'Radius'
	String get nearbyRadius => 'Radius';

	/// en: '${name} has been added to your directory!'
	String nearbySaved({required Object name}) => '${name} has been added to your directory!';

	/// en: '${name} is already in your directory.'
	String nearbyAlreadySaved({required Object name}) => '${name} is already in your directory.';

	/// en: 'Book Appointment'
	String get nearbyBookAppointment => 'Book Appointment';

	/// en: '© OpenStreetMap contributors'
	String get nearbyOsmAttribution => '© OpenStreetMap contributors';

	/// en: 'OpenStreetMap data: please verify information directly with the establishment.'
	String get nearbyOsmWarning => 'OpenStreetMap data: please verify information directly with the establishment.';

	/// en: 'Medical Orientation'
	String get orientationTitle => 'Medical Orientation';

	/// en: 'Which specialty should I consult?'
	String get orientationSubtitle => 'Which specialty should I consult?';

	/// en: 'This suggestion is general guidance, not a diagnosis. It does not replace medical advice. In case of emergency, call 190.'
	String get orientationDisclaimer => 'This suggestion is general guidance, not a diagnosis. It does not replace medical advice. In case of emergency, call 190.';

	/// en: 'Find the right specialty'
	String get orientationFindSpecialty => 'Find the right specialty';

	/// en: 'Describe what you feel (pain, location, duration)...'
	String get orientationSymptomsHint => 'Describe what you feel (pain, location, duration)...';

	/// en: 'Analyzing...'
	String get orientationAnalyzing => 'Analyzing...';

	/// en: 'Warning: Potential medical emergency'
	String get orientationEmergencyAlert => 'Warning: Potential medical emergency';

	/// en: 'Call Emergency (190)'
	String get orientationEmergencyCall => 'Call Emergency (190)';

	/// en: 'Orientation History'
	String get orientationHistory => 'Orientation History';

	/// en: 'No history recorded'
	String get orientationNoHistory => 'No history recorded';

	/// en: 'Clear all'
	String get orientationClearHistory => 'Clear all';
}

// Path: biologicalSexOptions
class Translations$biologicalSexOptions$en {
	Translations$biologicalSexOptions$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Male'
	String get male => 'Male';

	/// en: 'Female'
	String get female => 'Female';

	/// en: 'Other'
	String get other => 'Other';
}

// Path: rhesusOptions
class Translations$rhesusOptions$en {
	Translations$rhesusOptions$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Positive (+)'
	String get positive => 'Positive (+)';

	/// en: 'Negative (−)'
	String get negative => 'Negative (−)';
}

// Path: smokingStatus
class Translations$smokingStatus$en {
	Translations$smokingStatus$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Non-smoker'
	String get never => 'Non-smoker';

	/// en: 'Former smoker'
	String get former => 'Former smoker';

	/// en: 'Occasional'
	String get occasional => 'Occasional';

	/// en: 'Regular'
	String get regular => 'Regular';
}

// Path: alcoholConsumption
class Translations$alcoholConsumption$en {
	Translations$alcoholConsumption$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Never'
	String get none => 'Never';

	/// en: 'Occasional'
	String get occasional => 'Occasional';

	/// en: 'Moderate'
	String get moderate => 'Moderate';

	/// en: 'Frequent'
	String get frequent => 'Frequent';
}

// Path: physicalActivityOptions
class Translations$physicalActivityOptions$en {
	Translations$physicalActivityOptions$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Sedentary'
	String get sedentary => 'Sedentary';

	/// en: 'Light'
	String get light => 'Light';

	/// en: 'Moderate'
	String get moderate => 'Moderate';

	/// en: 'Intense'
	String get intense => 'Intense';
}

// Path: allergySeverityOptions
class Translations$allergySeverityOptions$en {
	Translations$allergySeverityOptions$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Mild'
	String get mild => 'Mild';

	/// en: 'Moderate'
	String get moderate => 'Moderate';

	/// en: 'Severe'
	String get severe => 'Severe';
}

// Path: allergyKindOptions
class Translations$allergyKindOptions$en {
	Translations$allergyKindOptions$en._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// en: 'Medication'
	String get medication => 'Medication';

	/// en: 'Food'
	String get food => 'Food';

	/// en: 'Other'
	String get other => 'Other';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'settings' => 'Settings',
			'accountSecurity' => 'Account & Security',
			'biometrics' => 'Biometrics (FaceID / Fingerprint)',
			'changePassword' => 'Change Password',
			'passwordResetSent' => 'A password reset link has been sent to your email.',
			'passwordResetError' => ({required Object error}) => 'Error sending reset link: ${error}',
			'passwordResetNoEmail' => 'No email associated with this account.',
			'biometricsEnabled' => 'Biometric authentication enabled.',
			'biometricsDisabled' => 'Biometric authentication disabled.',
			'biometricsNotSupported' => 'Biometrics not supported on this device.',
			'biometricsAuthFailed' => 'Biometric authentication failed or cancelled.',
			'biometricsPromptReason' => 'Confirm your identity to enable biometric authentication.',
			'logout' => 'Logout',
			'deleteAccount' => 'Delete Account',
			'appPreferences' => 'App Preferences',
			'theme' => 'Theme',
			'themeLight' => 'Light',
			'themeDark' => 'Dark',
			'themeSystem' => 'System',
			'language' => 'Language',
			'langFrench' => 'French',
			'langArabic' => 'Arabic',
			'langEnglish' => 'English',
			'metricSystem' => 'Metric System (kg, cm)',
			'metricSubtitle' => 'Disable for imperial (lbs, in)',
			'privacyMedical' => 'Privacy & Medical Data',
			'profileVisibility' => 'Profile Visibility',
			'profileVisibilitySub' => 'Allow doctors to view my record',
			'exportRecord' => 'Export Record (PDF/CSV)',
			'about' => 'About',
			'termsPrivacy' => 'Terms & Privacy Policy',
			'appVersion' => 'App Version',
			'navProfile' => 'Profile',
			'navMedications' => 'Medications',
			'navAppointments' => 'Appointments',
			'navTracking' => 'Tracking',
			'navDocuments' => 'Documents',
			'profileTitle' => 'Profile',
			'dashboard' => 'Dashboard',
			'medicalRecord' => 'Medical Record',
			'profileError' => 'Failed to load profile.',
			'retry' => 'Retry',
			'vitals' => 'Vitals',
			'lifestyle' => 'Lifestyle',
			'tooltipSettings' => 'Settings',
			'tooltipEditProfile' => 'Edit Profile',
			'userProfilePlaceholder' => 'User',
			'height' => 'Height',
			'weight' => 'Weight',
			'bmi' => 'Body Mass Index',
			'bmiUnderweight' => 'Underweight',
			'bmiNormal' => 'Normal weight',
			'bmiOverweight' => 'Overweight',
			'bmiObesity' => 'Obesity',
			'birthDate' => 'Date of Birth',
			'biologicalSex' => 'Biological Sex',
			'tobacco' => 'Tobacco',
			'alcohol' => 'Alcohol',
			'occasional' => 'Occasional',
			'diseases' => 'Diseases',
			'allergies' => 'Allergies',
			'history' => 'History',
			'chronic' => 'Chronic',
			'acute' => 'Acute',
			'last12Months' => 'Last 12 months',
			'last5Years' => 'Last 5 years',
			'older' => 'Older',
			'reset' => 'Reset',
			'bloodGroup' => 'Blood type',
			'age' => 'Age',
			'yearsOld' => 'years',
			'bmiPrompt' => 'Enter your height and weight\nto calculate your BMI.',
			'personalInfo' => 'Personal Information',
			'fullName' => 'Full Name',
			'physiologicalData' => 'Physiological Data',
			'rhesus' => 'Rhesus',
			'physicalActivity' => 'Physical Activity',
			'saveChanges' => 'Save Changes',
			'notSpecified' => 'Not specified',
			'profileCompletion' => 'Profile completion',
			'profileComplete' => 'Profile complete 🎉',
			'allInfoProvided' => 'All your information is provided.',
			'toComplete' => 'To complete: ',
			'completeMyProfile' => 'Complete my profile',
			'biologicalSexOptions.male' => 'Male',
			'biologicalSexOptions.female' => 'Female',
			'biologicalSexOptions.other' => 'Other',
			'rhesusOptions.positive' => 'Positive (+)',
			'rhesusOptions.negative' => 'Negative (−)',
			'smokingStatus.never' => 'Non-smoker',
			'smokingStatus.former' => 'Former smoker',
			'smokingStatus.occasional' => 'Occasional',
			'smokingStatus.regular' => 'Regular',
			'alcoholConsumption.none' => 'Never',
			'alcoholConsumption.occasional' => 'Occasional',
			'alcoholConsumption.moderate' => 'Moderate',
			'alcoholConsumption.frequent' => 'Frequent',
			'physicalActivityOptions.sedentary' => 'Sedentary',
			'physicalActivityOptions.light' => 'Light',
			'physicalActivityOptions.moderate' => 'Moderate',
			'physicalActivityOptions.intense' => 'Intense',
			'addCondition' => 'Add Disease',
			'addDisease' => 'Add Disease',
			'addAllergy' => 'Add Allergy',
			'addHistory' => 'Add Medical History',
			'addAntecedent' => 'Add Medical History',
			'add' => 'Add',
			'addHistoryTitle' => 'Add — Medical History',
			'historyTitle' => 'History title',
			'descriptionOptional' => 'Description (optional)',
			'addAllergyTitle' => 'Add — Allergy',
			'allergen' => 'Allergen',
			'severity' => 'Severity',
			'category' => 'Category',
			'allergySeverityOptions.mild' => 'Mild',
			'allergySeverityOptions.moderate' => 'Moderate',
			'allergySeverityOptions.severe' => 'Severe',
			'allergyKindOptions.medication' => 'Medication',
			'allergyKindOptions.food' => 'Food',
			'allergyKindOptions.other' => 'Other',
			'addDiseaseTitle' => 'Add — Disease',
			'diseaseName' => 'Disease name',
			'diagnosisDate' => 'Diagnosis date',
			'eventDate' => 'Event date',
			'chronicDisease' => 'Chronic condition',
			'editHistoryTitle' => 'Edit — Medical History',
			'editAllergyTitle' => 'Edit — Allergy',
			'editDiseaseTitle' => 'Edit — Disease',
			'requiredField' => 'This field is required',
			'minCharacters' => 'At least 2 characters',
			'maxCharacters' => '80 characters maximum',
			'selectDate' => 'Select a date',
			'clearDate' => 'Clear date',
			'date' => 'Date',
			'saveFailed' => 'Unable to save. Please try again.',
			'diagnosedIn' => ({required Object date}) => 'Diagnosed in ${date}',
			'unknownDate' => 'Unknown date',
			'nearbyTitle' => 'Nearby Doctors & Clinics',
			'nearbySearchHint' => 'Search doctor, clinic, specialty...',
			'nearbyRadius' => 'Radius',
			'nearbySaved' => ({required Object name}) => '${name} has been added to your directory!',
			'nearbyAlreadySaved' => ({required Object name}) => '${name} is already in your directory.',
			'nearbyBookAppointment' => 'Book Appointment',
			'nearbyOsmAttribution' => '© OpenStreetMap contributors',
			'nearbyOsmWarning' => 'OpenStreetMap data: please verify information directly with the establishment.',
			'orientationTitle' => 'Medical Orientation',
			'orientationSubtitle' => 'Which specialty should I consult?',
			'orientationDisclaimer' => 'This suggestion is general guidance, not a diagnosis. It does not replace medical advice. In case of emergency, call 190.',
			'orientationFindSpecialty' => 'Find the right specialty',
			'orientationSymptomsHint' => 'Describe what you feel (pain, location, duration)...',
			'orientationAnalyzing' => 'Analyzing...',
			'orientationEmergencyAlert' => 'Warning: Potential medical emergency',
			'orientationEmergencyCall' => 'Call Emergency (190)',
			'orientationHistory' => 'Orientation History',
			'orientationNoHistory' => 'No history recorded',
			'orientationClearHistory' => 'Clear all',
			_ => null,
		};
	}
}
