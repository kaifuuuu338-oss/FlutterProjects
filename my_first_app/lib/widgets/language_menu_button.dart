import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/localization/locale_provider.dart';

class LanguageMenuButton extends StatelessWidget {
  final Color? iconColor;
  final double? iconSize;

  const LanguageMenuButton({super.key, this.iconColor, this.iconSize});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopupMenuButton<String>(
      icon: Icon(Icons.language, color: iconColor, size: iconSize),
      onSelected: (code) => context.read<LocaleProvider>().setLocale(Locale(code)),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'en', child: Text(l10n.t('lang_english'))),
        PopupMenuItem(value: 'te', child: Text(l10n.t('lang_telugu'))),
        PopupMenuItem(value: 'hi', child: Text(l10n.t('lang_hindi'))),
      ],
    );
  }
}
