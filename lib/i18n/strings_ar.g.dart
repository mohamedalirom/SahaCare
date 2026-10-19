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
class TranslationsAr with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsAr({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ar,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ar>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key);

	late final TranslationsAr _root = this; // ignore: unused_field

	@override 
	TranslationsAr $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsAr(meta: meta ?? this.$meta);

	// Translations
	@override String get settings => 'الإعدادات';
	@override String get accountSecurity => 'الحساب والأمان';
	@override String get biometrics => 'البصمة (الوجه / الإصبع)';
	@override String get changePassword => 'تغيير كلمة المرور';
	@override String get passwordResetSent => 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.';
	@override String passwordResetError({required Object error}) => 'خطأ في إرسال رابط إعادة التعيين: ${error}';
	@override String get passwordResetNoEmail => 'لا يوجد بريد إلكتروني مرتبط بهذا الحساب.';
	@override String get biometricsEnabled => 'تم تفعيل المصادقة البيومترية.';
	@override String get biometricsDisabled => 'تم تعطيل المصادقة البيومترية.';
	@override String get biometricsNotSupported => 'المصادقة البيومترية غير مدعومة على هذا الجهاز.';
	@override String get biometricsAuthFailed => 'فشلت المصادقة البيومترية أو تم إلغاؤها.';
	@override String get biometricsPromptReason => 'يرجى تأكيد هويتك لتفعيل القفل البيومتري.';
	@override String get logout => 'تسجيل الخروج';
	@override String get deleteAccount => 'حذف الحساب';
	@override String get appPreferences => 'تفضيلات التطبيق';
	@override String get theme => 'المظهر';
	@override String get themeLight => 'فاتح';
	@override String get themeDark => 'داكن';
	@override String get themeSystem => 'النظام';
	@override String get language => 'اللغة';
	@override String get langFrench => 'الفرنسية';
	@override String get langArabic => 'العربية';
	@override String get langEnglish => 'الإنجليزية';
	@override String get metricSystem => 'النظام المتري (كجم، سم)';
	@override String get metricSubtitle => 'تعطيل للنظام الإمبراطوري';
	@override String get privacyMedical => 'الخصوصية والبيانات الطبية';
	@override String get profileVisibility => 'رؤية الملف الشخصي';
	@override String get profileVisibilitySub => 'السماح للأطباء بعرض ملفي';
	@override String get exportRecord => 'تصدير الملف (PDF/CSV)';
	@override String get about => 'حول';
	@override String get termsPrivacy => 'الشروط وسياسة الخصوصية';
	@override String get appVersion => 'إصدار التطبيق';
	@override String get navProfile => 'الملف الشخصي';
	@override String get navMedications => 'الأدوية';
	@override String get navAppointments => 'المواعيد';
	@override String get navTracking => 'المتابعة';
	@override String get navDocuments => 'المستندات';
	@override String get profileTitle => 'الملف الشخصي';
	@override String get dashboard => 'لوحة القيادة';
	@override String get medicalRecord => 'السجل الطبي';
	@override String get profileError => 'فشل في تحميل الملف الشخصي.';
	@override String get retry => 'إعادة المحاولة';
	@override String get vitals => 'العلامات الحيوية';
	@override String get lifestyle => 'نمط الحياة';
	@override String get tooltipSettings => 'الإعدادات';
	@override String get tooltipEditProfile => 'تعديل الملف الشخصي';
	@override String get userProfilePlaceholder => 'مستخدم';
	@override String get height => 'الطول';
	@override String get weight => 'الوزن';
	@override String get bmi => 'مؤشر كتلة الجسم';
	@override String get bmiUnderweight => 'نقص الوزن';
	@override String get bmiNormal => 'وزن طبيعي';
	@override String get bmiOverweight => 'زيادة الوزن';
	@override String get bmiObesity => 'السمنة';
	@override String get birthDate => 'تاريخ الميلاد';
	@override String get biologicalSex => 'الجنس البيولوجي';
	@override String get tobacco => 'التبغ';
	@override String get alcohol => 'الكحول';
	@override String get occasional => 'أحياناً';
	@override String get diseases => 'الأمراض';
	@override String get allergies => 'الحساسية';
	@override String get history => 'السوابق المرضية';
	@override String get chronic => 'مزمن';
	@override String get acute => 'حاد';
	@override String get last12Months => 'آخر 12 شهراً';
	@override String get last5Years => 'آخر 5 سنوات';
	@override String get older => 'أقدم';
	@override String get reset => 'إعادة ضبط';
	@override String get bloodGroup => 'فصيلة الدم';
	@override String get age => 'العمر';
	@override String get yearsOld => 'سنة';
	@override String get bmiPrompt => 'أدخل طولك ووزنك\nلحساب مؤشر كتلة الجسم.';
	@override String get personalInfo => 'المعلومات الشخصية';
	@override String get fullName => 'الاسم الكامل';
	@override String get physiologicalData => 'البيانات الفسيولوجية';
	@override String get rhesus => 'عامل ريسوس';
	@override String get physicalActivity => 'النشاط البدني';
	@override String get saveChanges => 'حفظ التغييرات';
	@override String get notSpecified => 'غير محدد';
	@override String get profileCompletion => 'اكتمال الملف الشخصي';
	@override String get profileComplete => 'الملف الشخصي مكتمل 🎉';
	@override String get allInfoProvided => 'تم ملء جميع معلوماتك.';
	@override String get toComplete => 'المتبقي للإكمال: ';
	@override String get completeMyProfile => 'إكمال ملفي الشخصي';
	@override late final _Translations$biologicalSexOptions$ar biologicalSexOptions = _Translations$biologicalSexOptions$ar._(_root);
	@override late final _Translations$rhesusOptions$ar rhesusOptions = _Translations$rhesusOptions$ar._(_root);
	@override late final _Translations$smokingStatus$ar smokingStatus = _Translations$smokingStatus$ar._(_root);
	@override late final _Translations$alcoholConsumption$ar alcoholConsumption = _Translations$alcoholConsumption$ar._(_root);
	@override late final _Translations$physicalActivityOptions$ar physicalActivityOptions = _Translations$physicalActivityOptions$ar._(_root);
	@override String get addCondition => 'إضافة مرض';
	@override String get addDisease => 'إضافة مرض';
	@override String get addAllergy => 'إضافة حساسية';
	@override String get addHistory => 'إضافة سابقة طبية';
	@override String get addAntecedent => 'إضافة سابقة طبية';
	@override String get add => 'إضافة';
	@override String get addHistoryTitle => 'إضافة — سابقة طبية';
	@override String get historyTitle => 'عنوان السابقة';
	@override String get descriptionOptional => 'الوصف (اختياري)';
	@override String get addAllergyTitle => 'إضافة — حساسية';
	@override String get allergen => 'مسبب الحساسية';
	@override String get severity => 'الشدة';
	@override String get category => 'الفئة';
	@override late final _Translations$allergySeverityOptions$ar allergySeverityOptions = _Translations$allergySeverityOptions$ar._(_root);
	@override late final _Translations$allergyKindOptions$ar allergyKindOptions = _Translations$allergyKindOptions$ar._(_root);
	@override String get addDiseaseTitle => 'إضافة — مرض';
	@override String get diseaseName => 'اسم المرض';
	@override String get diagnosisDate => 'تاريخ التشخيص';
	@override String get eventDate => 'تاريخ الحدث';
	@override String get chronicDisease => 'مرض مزمن';
	@override String get editHistoryTitle => 'تعديل — سابقة طبية';
	@override String get editAllergyTitle => 'تعديل — حساسية';
	@override String get editDiseaseTitle => 'تعديل — مرض';
	@override String get requiredField => 'هذا الحقل إجباري';
	@override String get minCharacters => 'حرفان على الأقل';
	@override String get maxCharacters => '80 حرفاً كحد أقصى';
	@override String get selectDate => 'تحديد تاريخ';
	@override String get clearDate => 'مسح التاريخ';
	@override String get date => 'التاريخ';
	@override String get saveFailed => 'تعذر الحفظ. يرجى المحاولة مرة أخرى.';
	@override String diagnosedIn({required Object date}) => 'تم التشخيص في ${date}';
	@override String get unknownDate => 'تاريخ غير معروف';
}

// Path: biologicalSexOptions
class _Translations$biologicalSexOptions$ar implements Translations$biologicalSexOptions$en {
	_Translations$biologicalSexOptions$ar._(this._root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get male => 'ذكر';
	@override String get female => 'أنثى';
	@override String get other => 'آخر';
}

// Path: rhesusOptions
class _Translations$rhesusOptions$ar implements Translations$rhesusOptions$en {
	_Translations$rhesusOptions$ar._(this._root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get positive => 'إيجابي (+)';
	@override String get negative => 'سلبي (−)';
}

// Path: smokingStatus
class _Translations$smokingStatus$ar implements Translations$smokingStatus$en {
	_Translations$smokingStatus$ar._(this._root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get never => 'غير مدخن';
	@override String get former => 'مدخن سابق';
	@override String get occasional => 'أحياناً';
	@override String get regular => 'منتظم';
}

// Path: alcoholConsumption
class _Translations$alcoholConsumption$ar implements Translations$alcoholConsumption$en {
	_Translations$alcoholConsumption$ar._(this._root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get none => 'أبداً';
	@override String get occasional => 'أحياناً';
	@override String get moderate => 'معتدل';
	@override String get frequent => 'متكرر';
}

// Path: physicalActivityOptions
class _Translations$physicalActivityOptions$ar implements Translations$physicalActivityOptions$en {
	_Translations$physicalActivityOptions$ar._(this._root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get sedentary => 'خامل';
	@override String get light => 'خفيف';
	@override String get moderate => 'معتدل';
	@override String get intense => 'مكثف';
}

// Path: allergySeverityOptions
class _Translations$allergySeverityOptions$ar implements Translations$allergySeverityOptions$en {
	_Translations$allergySeverityOptions$ar._(this._root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get mild => 'خفيفة';
	@override String get moderate => 'معتدلة';
	@override String get severe => 'شديدة';
}

// Path: allergyKindOptions
class _Translations$allergyKindOptions$ar implements Translations$allergyKindOptions$en {
	_Translations$allergyKindOptions$ar._(this._root);

	final TranslationsAr _root; // ignore: unused_field

	// Translations
	@override String get medication => 'دواء';
	@override String get food => 'غذائي';
	@override String get other => 'آخر';
}

/// The flat map containing all translations for locale <ar>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsAr {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'settings' => 'الإعدادات',
			'accountSecurity' => 'الحساب والأمان',
			'biometrics' => 'البصمة (الوجه / الإصبع)',
			'changePassword' => 'تغيير كلمة المرور',
			'passwordResetSent' => 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني.',
			'passwordResetError' => ({required Object error}) => 'خطأ في إرسال رابط إعادة التعيين: ${error}',
			'passwordResetNoEmail' => 'لا يوجد بريد إلكتروني مرتبط بهذا الحساب.',
			'biometricsEnabled' => 'تم تفعيل المصادقة البيومترية.',
			'biometricsDisabled' => 'تم تعطيل المصادقة البيومترية.',
			'biometricsNotSupported' => 'المصادقة البيومترية غير مدعومة على هذا الجهاز.',
			'biometricsAuthFailed' => 'فشلت المصادقة البيومترية أو تم إلغاؤها.',
			'biometricsPromptReason' => 'يرجى تأكيد هويتك لتفعيل القفل البيومتري.',
			'logout' => 'تسجيل الخروج',
			'deleteAccount' => 'حذف الحساب',
			'appPreferences' => 'تفضيلات التطبيق',
			'theme' => 'المظهر',
			'themeLight' => 'فاتح',
			'themeDark' => 'داكن',
			'themeSystem' => 'النظام',
			'language' => 'اللغة',
			'langFrench' => 'الفرنسية',
			'langArabic' => 'العربية',
			'langEnglish' => 'الإنجليزية',
			'metricSystem' => 'النظام المتري (كجم، سم)',
			'metricSubtitle' => 'تعطيل للنظام الإمبراطوري',
			'privacyMedical' => 'الخصوصية والبيانات الطبية',
			'profileVisibility' => 'رؤية الملف الشخصي',
			'profileVisibilitySub' => 'السماح للأطباء بعرض ملفي',
			'exportRecord' => 'تصدير الملف (PDF/CSV)',
			'about' => 'حول',
			'termsPrivacy' => 'الشروط وسياسة الخصوصية',
			'appVersion' => 'إصدار التطبيق',
			'navProfile' => 'الملف الشخصي',
			'navMedications' => 'الأدوية',
			'navAppointments' => 'المواعيد',
			'navTracking' => 'المتابعة',
			'navDocuments' => 'المستندات',
			'profileTitle' => 'الملف الشخصي',
			'dashboard' => 'لوحة القيادة',
			'medicalRecord' => 'السجل الطبي',
			'profileError' => 'فشل في تحميل الملف الشخصي.',
			'retry' => 'إعادة المحاولة',
			'vitals' => 'العلامات الحيوية',
			'lifestyle' => 'نمط الحياة',
			'tooltipSettings' => 'الإعدادات',
			'tooltipEditProfile' => 'تعديل الملف الشخصي',
			'userProfilePlaceholder' => 'مستخدم',
			'height' => 'الطول',
			'weight' => 'الوزن',
			'bmi' => 'مؤشر كتلة الجسم',
			'bmiUnderweight' => 'نقص الوزن',
			'bmiNormal' => 'وزن طبيعي',
			'bmiOverweight' => 'زيادة الوزن',
			'bmiObesity' => 'السمنة',
			'birthDate' => 'تاريخ الميلاد',
			'biologicalSex' => 'الجنس البيولوجي',
			'tobacco' => 'التبغ',
			'alcohol' => 'الكحول',
			'occasional' => 'أحياناً',
			'diseases' => 'الأمراض',
			'allergies' => 'الحساسية',
			'history' => 'السوابق المرضية',
			'chronic' => 'مزمن',
			'acute' => 'حاد',
			'last12Months' => 'آخر 12 شهراً',
			'last5Years' => 'آخر 5 سنوات',
			'older' => 'أقدم',
			'reset' => 'إعادة ضبط',
			'bloodGroup' => 'فصيلة الدم',
			'age' => 'العمر',
			'yearsOld' => 'سنة',
			'bmiPrompt' => 'أدخل طولك ووزنك\nلحساب مؤشر كتلة الجسم.',
			'personalInfo' => 'المعلومات الشخصية',
			'fullName' => 'الاسم الكامل',
			'physiologicalData' => 'البيانات الفسيولوجية',
			'rhesus' => 'عامل ريسوس',
			'physicalActivity' => 'النشاط البدني',
			'saveChanges' => 'حفظ التغييرات',
			'notSpecified' => 'غير محدد',
			'profileCompletion' => 'اكتمال الملف الشخصي',
			'profileComplete' => 'الملف الشخصي مكتمل 🎉',
			'allInfoProvided' => 'تم ملء جميع معلوماتك.',
			'toComplete' => 'المتبقي للإكمال: ',
			'completeMyProfile' => 'إكمال ملفي الشخصي',
			'biologicalSexOptions.male' => 'ذكر',
			'biologicalSexOptions.female' => 'أنثى',
			'biologicalSexOptions.other' => 'آخر',
			'rhesusOptions.positive' => 'إيجابي (+)',
			'rhesusOptions.negative' => 'سلبي (−)',
			'smokingStatus.never' => 'غير مدخن',
			'smokingStatus.former' => 'مدخن سابق',
			'smokingStatus.occasional' => 'أحياناً',
			'smokingStatus.regular' => 'منتظم',
			'alcoholConsumption.none' => 'أبداً',
			'alcoholConsumption.occasional' => 'أحياناً',
			'alcoholConsumption.moderate' => 'معتدل',
			'alcoholConsumption.frequent' => 'متكرر',
			'physicalActivityOptions.sedentary' => 'خامل',
			'physicalActivityOptions.light' => 'خفيف',
			'physicalActivityOptions.moderate' => 'معتدل',
			'physicalActivityOptions.intense' => 'مكثف',
			'addCondition' => 'إضافة مرض',
			'addDisease' => 'إضافة مرض',
			'addAllergy' => 'إضافة حساسية',
			'addHistory' => 'إضافة سابقة طبية',
			'addAntecedent' => 'إضافة سابقة طبية',
			'add' => 'إضافة',
			'addHistoryTitle' => 'إضافة — سابقة طبية',
			'historyTitle' => 'عنوان السابقة',
			'descriptionOptional' => 'الوصف (اختياري)',
			'addAllergyTitle' => 'إضافة — حساسية',
			'allergen' => 'مسبب الحساسية',
			'severity' => 'الشدة',
			'category' => 'الفئة',
			'allergySeverityOptions.mild' => 'خفيفة',
			'allergySeverityOptions.moderate' => 'معتدلة',
			'allergySeverityOptions.severe' => 'شديدة',
			'allergyKindOptions.medication' => 'دواء',
			'allergyKindOptions.food' => 'غذائي',
			'allergyKindOptions.other' => 'آخر',
			'addDiseaseTitle' => 'إضافة — مرض',
			'diseaseName' => 'اسم المرض',
			'diagnosisDate' => 'تاريخ التشخيص',
			'eventDate' => 'تاريخ الحدث',
			'chronicDisease' => 'مرض مزمن',
			'editHistoryTitle' => 'تعديل — سابقة طبية',
			'editAllergyTitle' => 'تعديل — حساسية',
			'editDiseaseTitle' => 'تعديل — مرض',
			'requiredField' => 'هذا الحقل إجباري',
			'minCharacters' => 'حرفان على الأقل',
			'maxCharacters' => '80 حرفاً كحد أقصى',
			'selectDate' => 'تحديد تاريخ',
			'clearDate' => 'مسح التاريخ',
			'date' => 'التاريخ',
			'saveFailed' => 'تعذر الحفظ. يرجى المحاولة مرة أخرى.',
			'diagnosedIn' => ({required Object date}) => 'تم التشخيص في ${date}',
			'unknownDate' => 'تاريخ غير معروف',
			_ => null,
		};
	}
}
