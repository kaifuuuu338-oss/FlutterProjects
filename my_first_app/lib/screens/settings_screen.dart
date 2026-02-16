import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/localization/locale_provider.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool offlineDrafts = true;
  bool autoSync = true;
  bool maskPii = true;
  bool largeText = false;
  int autoLogoutMinutes = 15;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('settings')),
        backgroundColor: const Color(0xFF0D5BA7),
        foregroundColor: Colors.white,
        actions: const [
          LanguageMenuButton(iconColor: Colors.white),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _sectionTitle(l10n.t('section_language')),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.language, color: Color(0xFF0D5BA7)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: context.read<LocaleProvider>().locale.languageCode,
                      decoration: const InputDecoration(border: InputBorder.none),
                      items: [
                        DropdownMenuItem(value: 'en', child: Text(l10n.t('lang_english'))),
                        DropdownMenuItem(value: 'te', child: Text(l10n.t('lang_telugu'))),
                        DropdownMenuItem(value: 'hi', child: Text(l10n.t('lang_hindi'))),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        context.read<LocaleProvider>().setLocale(Locale(value));
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _sectionTitle(l10n.t('section_field_mode')),
          _toggleCard(l10n.t('save_drafts_offline'), offlineDrafts, (v) => setState(() => offlineDrafts = v), Icons.save_alt),
          _toggleCard(l10n.t('auto_sync_internet_returns'), autoSync, (v) => setState(() => autoSync = v), Icons.sync),
          _toggleCard(l10n.t('mask_parent_pii'), maskPii, (v) => setState(() => maskPii = v), Icons.privacy_tip_outlined),
          _toggleCard(l10n.t('large_text_for_aww'), largeText, (v) => setState(() => largeText = v), Icons.text_fields),
          const SizedBox(height: 10),
          _sectionTitle(l10n.t('section_security')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.timer_outlined, color: Color(0xFF0D5BA7)),
              title: Text(l10n.t('auto_logout_minutes')),
              trailing: DropdownButton<int>(
                value: autoLogoutMinutes,
                items: const [
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 15, child: Text('15')),
                  DropdownMenuItem(value: 30, child: Text('30')),
                  DropdownMenuItem(value: 60, child: Text('60')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => autoLogoutMinutes = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          _sectionTitle(l10n.t('section_support')),
          Card(
            child: ListTile(
              leading: const Icon(Icons.support_agent, color: Color(0xFF0D5BA7)),
              title: Text(l10n.t('help_line')),
              subtitle: Text(l10n.t('help_line_number', {'number': '9000-355-3220'})),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Color(0xFF0D5BA7)),
              title: Text(l10n.t('app_version')),
              subtitle: Text(l10n.t('app_version_value')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF174A7E)),
      ),
    );
  }

  Widget _toggleCard(String title, bool value, ValueChanged<bool> onChanged, IconData icon) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFF0D5BA7)),
        title: Text(title),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
