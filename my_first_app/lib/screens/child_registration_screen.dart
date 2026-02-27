import 'package:flutter/material.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/models/child_model.dart';
import 'package:my_first_app/models/screening_model.dart';
import 'package:my_first_app/screens/consent_screen.dart';
import 'package:my_first_app/screens/dashboard_screen.dart';
import 'package:my_first_app/screens/result_screen.dart';
import 'package:my_first_app/screens/settings_screen.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/auth_service.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class ChildRegistrationScreen extends StatefulWidget {
  const ChildRegistrationScreen({super.key});

  @override
  State<ChildRegistrationScreen> createState() =>
      _ChildRegistrationScreenState();
}

class _ChildRegistrationScreenState extends State<ChildRegistrationScreen> {
  static const List<String> _assessmentCycles = ['Baseline'];

  final _formKey = GlobalKey<FormState>();
  final APIService _api = APIService();
  final AuthService _auth = AuthService();
  final LocalDBService _localDb = LocalDBService();
  final TextEditingController _childIdController = TextEditingController(
    text: 'child_001',
  );
  final TextEditingController _awcCodeController = TextEditingController(
    text: 'AWW_DEMO_001',
  );
  final TextEditingController _dobController = TextEditingController();

  DateTime? _dob;
  final String _gender = 'M';
  String _assessmentCycle = 'Baseline';
  String? _district;
  String? _mandal;
  int _ageMonths = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLoggedInUserData();
  }

  Future<void> _loadLoggedInUserData() async {
    try {
      final aww = await _auth.getCurrentUserAww();
      final savedAwcCode =
          (await _auth.getLoggedInAwcCode() ?? '').trim().toUpperCase();
      final resolvedAwcCode = aww?.awcCode.trim().isNotEmpty == true
          ? aww!.awcCode.trim().toUpperCase()
          : savedAwcCode;
      final mappedLocation = resolvedAwcCode.isNotEmpty
          ? AppConstants.getAwcMapping(resolvedAwcCode)
          : const <String, String>{};

      final profileLocation = await _loadLocationFromBackendProfile(
        resolvedAwcCode,
      );
      final childrenLocation = await _inferLocationFromRegisteredChildren(
        resolvedAwcCode,
      );

      final rawDistrict = profileLocation['district']!.isNotEmpty
          ? profileLocation['district']!
          : childrenLocation['district']!.isNotEmpty
              ? childrenLocation['district']!
              : (aww?.district ?? '').trim().isNotEmpty
                  ? aww!.district.trim()
                  : (mappedLocation['district'] ?? '').trim();
      final rawMandal = profileLocation['mandal']!.isNotEmpty
          ? profileLocation['mandal']!
          : childrenLocation['mandal']!.isNotEmpty
              ? childrenLocation['mandal']!
              : (aww?.mandal ?? '').trim().isNotEmpty
                  ? aww!.mandal.trim()
                  : (mappedLocation['mandal'] ?? '').trim();

      String? resolvedDistrict = _canonicalDistrict(rawDistrict);
      String? resolvedMandal = _canonicalMandal(resolvedDistrict, rawMandal);

      if (resolvedMandal == null && rawMandal.isNotEmpty) {
        final districtByMandal = _findDistrictByMandal(rawMandal);
        if (districtByMandal != null) {
          resolvedDistrict = districtByMandal;
          resolvedMandal = _canonicalMandal(resolvedDistrict, rawMandal);
        }
      }

      if (resolvedDistrict != null && resolvedMandal == null) {
        final fallbacks = _mandalsForDistrictName(resolvedDistrict);
        if (fallbacks.isNotEmpty) {
          resolvedMandal = fallbacks.first;
        }
      }

      if (resolvedAwcCode.isNotEmpty &&
          resolvedDistrict != null &&
          resolvedMandal != null) {
        await _auth.saveLoggedInAwwProfile(
          awcCode: resolvedAwcCode,
          district: resolvedDistrict,
          mandal: resolvedMandal,
        );
      }

      if (mounted) {
        setState(() {
          if (resolvedAwcCode.isNotEmpty) {
            _awcCodeController.text = resolvedAwcCode;
          }
          _district = resolvedDistrict;
          _mandal = resolvedMandal;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, String>> _loadLocationFromBackendProfile(
    String awcCode,
  ) async {
    if (awcCode.trim().isEmpty) {
      return const {'district': '', 'mandal': ''};
    }
    try {
      final profile = await _api.getAwwProfile(awcCode);
      if (profile == null) {
        return const {'district': '', 'mandal': ''};
      }
      return {
        'district': (profile['district'] ?? '').toString().trim(),
        'mandal': (profile['mandal'] ?? '').toString().trim(),
      };
    } catch (_) {
      return const {'district': '', 'mandal': ''};
    }
  }

  Future<Map<String, String>> _inferLocationFromRegisteredChildren(
    String awcCode,
  ) async {
    if (awcCode.trim().isEmpty) {
      return const {'district': '', 'mandal': ''};
    }
    try {
      final items = await _api.getRegisteredChildren(limit: 200, awcCode: awcCode);
      if (items.isEmpty) {
        return const {'district': '', 'mandal': ''};
      }

      final counts = <String, int>{};
      for (final row in items) {
        final district = (row['district'] ?? row['district_id'] ?? '')
            .toString()
            .trim();
        final mandal = (row['mandal'] ?? row['mandal_id'] ?? '')
            .toString()
            .trim();
        if (district.isEmpty || mandal.isEmpty) continue;
        final key = '${district.toLowerCase()}|${mandal.toLowerCase()}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
      if (counts.isEmpty) {
        return const {'district': '', 'mandal': ''};
      }

      String? bestKey;
      int bestCount = -1;
      counts.forEach((key, value) {
        if (value > bestCount) {
          bestKey = key;
          bestCount = value;
        }
      });
      if (bestKey == null) {
        return const {'district': '', 'mandal': ''};
      }
      final parts = bestKey!.split('|');
      if (parts.length != 2) {
        return const {'district': '', 'mandal': ''};
      }

      final bestDistrict = items
          .map((row) => (row['district'] ?? row['district_id'] ?? '')
              .toString()
              .trim())
          .firstWhere(
            (d) => d.toLowerCase() == parts[0],
            orElse: () => parts[0],
          );
      final bestMandal = items
          .map((row) => (row['mandal'] ?? row['mandal_id'] ?? '')
              .toString()
              .trim())
          .firstWhere(
            (m) => m.toLowerCase() == parts[1],
            orElse: () => parts[1],
          );

      return {'district': bestDistrict, 'mandal': bestMandal};
    } catch (_) {
      return const {'district': '', 'mandal': ''};
    }
  }

  @override
  void dispose() {
    _childIdController.dispose();
    _awcCodeController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  int _calculateAgeMonths(DateTime dob) {
    final now = DateTime.now();
    return (now.year - dob.year) * 12 + (now.month - dob.month);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(2060, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _ageMonths = _calculateAgeMonths(picked);
      _dobController.text = _formatDate(picked);
    });
  }

  List<String> _uniqueNonEmpty(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in values) {
      final value = raw.trim();
      if (value.isEmpty) continue;
      final key = value.toLowerCase();
      if (seen.add(key)) {
        result.add(value);
      }
    }
    return result;
  }

  List<String> _mandalsForDistrictName(String district) {
    return _uniqueNonEmpty(
      AppConstants.apDistrictMandals[district] ?? const <String>[],
    );
  }

  String? _canonicalDistrict(String? district) {
    final candidate = (district ?? '').trim();
    if (candidate.isEmpty) return null;
    for (final item in _districts) {
      if (item.toLowerCase() == candidate.toLowerCase()) {
        return item;
      }
    }
    return null;
  }

  String? _canonicalMandal(String? district, String? mandal) {
    final districtValue = _canonicalDistrict(district);
    final mandalValue = (mandal ?? '').trim();
    if (districtValue == null || mandalValue.isEmpty) return null;
    final mandals = _mandalsForDistrictName(districtValue);
    for (final item in mandals) {
      if (item.toLowerCase() == mandalValue.toLowerCase()) {
        return item;
      }
    }
    for (final item in mandals) {
      if (item.toLowerCase().startsWith(mandalValue.toLowerCase())) {
        return item;
      }
    }
    return null;
  }

  String? _findDistrictByMandal(String mandal) {
    final target = mandal.trim();
    if (target.isEmpty) return null;

    for (final district in _districts) {
      final mandals = _mandalsForDistrictName(district);
      for (final item in mandals) {
        if (item.toLowerCase() == target.toLowerCase()) {
          return district;
        }
      }
    }

    for (final district in _districts) {
      final mandals = _mandalsForDistrictName(district);
      for (final item in mandals) {
        if (item.toLowerCase().startsWith(target.toLowerCase())) {
          return district;
        }
      }
    }
    return null;
  }

  List<String> get _districts {
    final items = _uniqueNonEmpty(AppConstants.apDistrictMandals.keys);
    items.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return items;
  }

  List<String> get _mandalsForDistrict {
    final district = _canonicalDistrict(_district);
    if (district == null) return const [];
    return _mandalsForDistrictName(district);
  }

  Future<void> _registerChild() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('please_select_dob')),
        ),
      );
      return;
    }
    if (_district == null || _mandal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).t('please_select_district_and_mandal'),
          ),
        ),
      );
      return;
    }

    // Check for duplicate registration
    final awcCode = _awcCodeController.text.trim();
    try {
      final existingChildren = await _api.getRegisteredChildren(awcCode: awcCode);
      
      // Check if a child with same district, mandal, and awc_code already exists
      final isDuplicate = existingChildren.any((child) {
        final childDistrict = child['district']?.toString().trim() ?? '';
        final childMandal = child['mandal']?.toString().trim() ?? '';
        final childAwcCode = child['awc_code']?.toString().trim().toUpperCase() ?? '';
        
        return childDistrict.toLowerCase() == _district!.toLowerCase() &&
               childMandal.toLowerCase() == _mandal!.toLowerCase() &&
               childAwcCode == awcCode.toUpperCase();
      });

      if (isDuplicate) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('USER already exist'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } catch (e) {
      // If we can't check for duplicates, log the error but continue
      print('Error checking for duplicate registration: $e');
    }

    final child = ChildModel(
      childId: _childIdController.text.trim(),
      childName: _childIdController.text.trim(),
      dateOfBirth: _dob!,
      ageMonths: _ageMonths,
      gender: _gender,
      awcCode: _awcCodeController.text.trim(),
      mandal: _mandal!,
      district: _district!,
      parentName: '',
      parentMobile: '',
      aadhaar: null,
      address: null,
      awwId: 'demo_aww_001',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      await _api.registerChild(child, assessmentCycle: _assessmentCycle);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PostgreSQL save failed. Backend not reachable at '
            '${AppConstants.baseUrl}. Start backend and retry. Error: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    await _localDb.initialize();
    await _localDb.saveChild(child);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Child saved to PostgreSQL ecd_data'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConsentScreen(
          childId: child.childId,
          ageMonths: child.ageMonths,
          awwId: child.awwId,
        ),
      ),
    );
  }

  void _openDashboard() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _viewRegisteredChildren() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('registered_children')),
        content: SizedBox(
          width: double.maxFinite,
          child: children.isEmpty
              ? Text(AppLocalizations.of(context).t('no_children_registered'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: children.length,
                  itemBuilder: (context, index) {
                    final c = children[index];
                    final genderLabel = c.gender == 'M'
                        ? AppLocalizations.of(context).t('gender_male')
                        : AppLocalizations.of(context).t('gender_female');
                    return ListTile(
                      title: Text(c.childId),
                      subtitle: Text(
                        '${AppLocalizations.of(context).t('age_with_months', {'age': '${c.ageMonths}'})} | $genderLabel',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).t('close')),
          ),
        ],
      ),
    );
  }

  Future<void> _viewPastResults() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final past = <ScreeningModel>[];
    for (final ChildModel c in children) {
      past.addAll(_localDb.getChildScreenings(c.childId));
    }
    past.sort((a, b) => b.screeningDate.compareTo(a.screeningDate));

    if (!mounted) return;
    if (past.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).t('no_past_results')),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: past.length,
        itemBuilder: (context, index) {
          final s = past[index];
          final risk = s.overallRisk.toString().split('.').last;
          return ListTile(
            title: Text(
              '${s.childId} - ${AppLocalizations.of(context).t(risk.toLowerCase()).toUpperCase()}',
            ),
            subtitle: Text(
              AppLocalizations.of(
                context,
              ).t('date_label', {'date': '${s.screeningDate.toLocal()}'}),
            ),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ResultScreen(
                    domainScores: s.domainScores,
                    overallRisk: risk,
                    missedMilestones: s.missedMilestones,
                    explainability: s.explainability,
                    childId: s.childId,
                    awwId: s.awwId,
                    ageMonths: s.ageMonths,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showRiskStatus() async {
    await _localDb.initialize();
    final children = _localDb.getAllChildren();
    final all = <ScreeningModel>[];
    for (final ChildModel c in children) {
      all.addAll(_localDb.getChildScreenings(c.childId));
    }
    final low = all.where((s) => s.overallRisk == RiskLevel.low).length;
    final medium = all.where((s) => s.overallRisk == RiskLevel.medium).length;
    final high = all.where((s) => s.overallRisk == RiskLevel.high).length;
    final critical = all
        .where((s) => s.overallRisk == RiskLevel.critical)
        .length;
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).t('risk_status')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${AppLocalizations.of(context).t('low')}: $low'),
            Text('${AppLocalizations.of(context).t('medium')}: $medium'),
            Text('${AppLocalizations.of(context).t('high')}: $high'),
            Text('${AppLocalizations.of(context).t('critical')}: $critical'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).t('ok')),
          ),
        ],
      ),
    );
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: const Color(0xFF2E8B57),
          child: SafeArea(
            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/ap_logo.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      width: 44,
                      height: 44,
                      color: Colors.white,
                      child: Center(child: Text(l10n.t('ap_short'))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  AppLocalizations.of(context).t('govt_andhra_pradesh'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const LanguageMenuButton(iconColor: Colors.white),
              ],
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          // Left navigation placeholder to visually match the design
          Container(
            width: 220,
            color: const Color(0xFFF5F5F5),
            child: Column(
              children: [
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Row(
                    children: [
                      ClipOval(
                        child: Image.asset(
                          'assets/images/ap_logo.png',
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).t('govt_andhra_pradesh'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                // simple nav items
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: Text(AppLocalizations.of(context).t('dashboard')),
                  onTap: _openDashboard,
                ),
                ListTile(
                  leading: const Icon(Icons.child_care),
                  title: Text(AppLocalizations.of(context).t('children')),
                  onTap: _viewRegisteredChildren,
                ),
                ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: Text(AppLocalizations.of(context).t('risk_status')),
                  onTap: _showRiskStatus,
                ),
                ListTile(
                  leading: const Icon(Icons.show_chart),
                  title: Text(
                    AppLocalizations.of(context).t('view_past_results'),
                  ),
                  onTap: _viewPastResults,
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: Text(AppLocalizations.of(context).t('settings')),
                  onTap: _openSettings,
                ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).t('register_child_title'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _childIdController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).t('child_id'),
                          prefixIcon: const Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(
                                context,
                              ).t('child_id_required')
                            : null,
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _dobController,
                        readOnly: true,
                        onTap: _pickDob,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).t('dob'),
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          hintText: AppLocalizations.of(context).t('dob_hint'),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(
                                context,
                              ).t('please_select_dob')
                            : null,
                      ),
                      const SizedBox(height: 6),
                      if (_dob != null)
                        Text(
                          AppLocalizations.of(
                            context,
                          ).t('age_with_months', {'age': '$_ageMonths'}),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: _awcCodeController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).t('awc_code'),
                          prefixIcon: const Icon(Icons.home_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(
                                context,
                              ).t('aws_code_required')
                            : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _district != null &&
                                _districts.contains(_district)
                            ? _district
                            : null,
                        items: _districts
                            .map(
                              (d) => DropdownMenuItem<String>(
                                value: d,
                                child: Text(d),
                              ),
                            )
                            .toList(),
                        onChanged: null,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).t('district'),
                          prefixIcon: const Icon(Icons.location_city),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(context).t('select_district')
                            : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _mandal != null &&
                                _mandalsForDistrict.contains(_mandal)
                            ? _mandal
                            : null,
                        items: _mandalsForDistrict
                            .map(
                              (m) => DropdownMenuItem<String>(
                                value: m,
                                child: Text(m),
                              ),
                            )
                            .toList(),
                        onChanged: null,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context).t('mandal'),
                          prefixIcon: const Icon(Icons.map_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? AppLocalizations.of(context).t('select_mandal')
                            : null,
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: _assessmentCycle,
                        items: _assessmentCycles
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).t(c.toLowerCase()),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _assessmentCycle = value);
                        },
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(
                            context,
                          ).t('assessment_cycle'),
                          prefixIcon: const Icon(Icons.assignment_outlined),
                        ),
                      ),
                      const SizedBox(height: 18),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _registerChild,
                          child: Text(l10n.t('register')),
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
    );
  }
}
