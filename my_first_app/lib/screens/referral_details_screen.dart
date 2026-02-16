import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class ReferralDetailsScreen extends StatelessWidget {
  final String referralId;
  final String childId;
  final String awwId;
  final int ageMonths;
  final String overallRisk;
  final String referralType;
  final String urgency;
  final DateTime createdAt;
  final DateTime expectedFollowUpDate;
  final String? notes;
  final List<String> reasons;

  const ReferralDetailsScreen({
    super.key,
    required this.referralId,
    required this.childId,
    required this.awwId,
    required this.ageMonths,
    required this.overallRisk,
    required this.referralType,
    required this.urgency,
    required this.createdAt,
    required this.expectedFollowUpDate,
    required this.reasons,
    this.notes,
  });

  String _formatDate(DateTime date) {
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '${date.year}-$mm-$dd';
  }

  Color _riskColor(String risk) {
    final r = risk.trim().toLowerCase();
    if (r == 'critical' || r == 'high') return const Color(0xFFE53935);
    if (r == 'medium') return const Color(0xFFF9A825);
    return const Color(0xFF43A047);
  }

  String _riskLabel(String risk, AppLocalizations l10n) {
    switch (risk.trim().toLowerCase()) {
      case 'critical':
        return l10n.t('critical');
      case 'high':
        return l10n.t('high');
      case 'medium':
        return l10n.t('medium');
      case 'low':
        return l10n.t('low');
      default:
        return risk;
    }
  }
  String _urgencyLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'Immediate':
        return l10n.t('urgency_immediate');
      case 'Urgent':
        return l10n.t('urgency_urgent');
      default:
        return l10n.t('urgency_normal');
    }
  }


  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF3F7FB), Color(0xFFE9F1F8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                height: isWide ? 180 : 150,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: const LanguageMenuButton(iconColor: Colors.white),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      padding: const EdgeInsets.all(6),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/ap_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Center(
                            child: Text(AppLocalizations.of(context).t('ap_short'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AppLocalizations.of(context).t('govt_andhra_pradesh'),
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context).t('referral_summary'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isWide ? 22 : 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        children: [
                          Card(
                            elevation: 8,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _riskColor(overallRisk),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Text(
                                          _riskLabel(overallRisk, l10n).toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        l10n.t('referral_number', {'id': referralId}),
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _infoTile(AppLocalizations.of(context).t('child_id'), childId),
                                      _infoTile(AppLocalizations.of(context).t('aww_id'), awwId),
                                      _infoTile(AppLocalizations.of(context).t('age_months_label'), ageMonths.toString()),
                                      _infoTile(AppLocalizations.of(context).t('referral_type'), referralType),
                                      _infoTile(AppLocalizations.of(context).t('urgency'), _urgencyLabel(urgency, l10n)),
                                      _infoTile(AppLocalizations.of(context).t('created_on'), _formatDate(createdAt)),
                                      _infoTile(AppLocalizations.of(context).t('follow_up_by'), _formatDate(expectedFollowUpDate)),

                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(AppLocalizations.of(context).t('reasons'), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])),
                                  const SizedBox(height: 8),
                                  if (reasons.isEmpty)
                                    Text(AppLocalizations.of(context).t('no_specific_domain_triggers'))
                                  else
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: reasons
                                          .map((r) => Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFF3E0),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(r, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                              ))
                                          .toList(),
                                    ),
                                  const SizedBox(height: 16),
                                  Text(AppLocalizations.of(context).t('notes'), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey[800])),
                                  const SizedBox(height: 6),
                                  Text((notes == null || notes!.trim().isEmpty) ? '-' : notes!),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppLocalizations.of(context).t('next_steps'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 8),
                                  _stepRow('1', AppLocalizations.of(context).t('next_step_1')),
                                  _stepRow('2', AppLocalizations.of(context).t('next_step_2')),
                                  _stepRow('3', AppLocalizations.of(context).t('next_step_3')),
                                  const SizedBox(height: 10),
                                  Text(
                                    l10n.t('data_usage_disclaimer'),
                                    style: TextStyle(color: Colors.grey[700], fontSize: 11, height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(l10n.t('close')),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE1E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF5D6B78), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _stepRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(num, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}
