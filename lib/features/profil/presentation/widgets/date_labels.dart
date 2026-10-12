import 'package:intl/intl.dart';
import '../../../../i18n/strings.g.dart';

/// Formats date according to active slang locale.
String formatDate(DateTime d, [String? locale]) {
  final loc = locale ?? LocaleSettings.currentLocale.languageCode;
  return DateFormat.yMd(loc).format(d);
}

/// Formats month and year according to active slang locale (e.g. "October 2026", "octobre 2026").
String formatMonthYear(DateTime d, [String? locale]) {
  final loc = locale ?? LocaleSettings.currentLocale.languageCode;
  return DateFormat.yMMMM(loc).format(d);
}
