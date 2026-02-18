import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;
  late Map<String, dynamic> _map;

  static const supportedLocales = [
    Locale('en'),
    Locale('te'),
    Locale('hi'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final value = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(value != null, 'AppLocalizations not found in context');
    return value!;
  }

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/localization/${locale.languageCode}.json');
    _map = jsonDecode(raw) as Map<String, dynamic>;
  }

  String t(String key, [Map<String, String>? params]) {
    final value = _map[key];
    if (value is String) {
      if (params == null || params.isEmpty) return value;
      var text = value;
      params.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
      return text;
    }
    return key;
  }

  /// Return localized questions for the given age (grouped by domain).
  ///
  /// The JSON files include a top-level `questions` object with age-group keys
  /// (q0_12, q12_24, q24_36, q36_48, q48_60, q60_72) and domain arrays.
  Map<String, List<String>> getQuestionsForAge(int ageMonths) {
    String groupKey;
    if (ageMonths <= 12) {
      groupKey = 'q0_12';
    } else {
      final years = ageMonths ~/ 12;
      if (years <= 2) {
        groupKey = 'q12_24';
      } else if (years == 3) groupKey = 'q24_36';
      else if (years == 4) groupKey = 'q36_48';
      else if (years == 5) groupKey = 'q48_60';
      else groupKey = 'q60_72';
    }

    final questionsSection = _map['questions'];
    if (questionsSection is! Map) return <String, List<String>>{};
    final group = questionsSection[groupKey];
    if (group is! Map) return <String, List<String>>{};

    final result = <String, List<String>>{};
    group.forEach((domain, items) {
      if (items is List) result['$domain'] = items.map((e) => '$e').toList();
    });
    return result;
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'te', 'hi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
