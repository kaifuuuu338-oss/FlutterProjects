import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/models/aww_model.dart';
import 'package:my_first_app/services/auth_service.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  static final RegExp _awcCodePattern = RegExp(r'^(AWW|AWS)_DEMO_\d{3}$');
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _awcController = TextEditingController(text: 'AWW_DEMO_001');

  final AuthService _auth = AuthService();
  final APIService _apiService = APIService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _loading = false;
  bool _obscure = true;
  String? _district;
  String? _mandal;
  static const Set<String> _excludedDistrictsForRegistration = {
    'Kanigiri (Merged/Restructured)',
    'Madanapalle (New)',
  };

  Map<String, List<String>> get _registrationDistrictMandals {
    final filtered = <String, List<String>>{};
    for (final entry in AppConstants.apDistrictMandals.entries) {
      if (_excludedDistrictsForRegistration.contains(entry.key)) {
        continue;
      }
      filtered[entry.key] = List<String>.from(entry.value);
    }
    return filtered;
  }

  List<String> get _districts {
    final items = _registrationDistrictMandals.keys.toList();
    items.sort();
    return items;
  }

  List<String> get _mandalsForDistrict {
    if (_district == null) return const [];
    return _registrationDistrictMandals[_district] ?? const [];
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    _awcController.dispose();
    super.dispose();
  }

  Future<void> _showAlreadyRegisteredDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Already registered'),
        content: const Text(
          'This AWW code is already registered for the selected district and mandal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _registerWithGoogle() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return; // User cancelled
      }

      // Create a registration record from Google account
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final awwId = 'aww_$timestamp';
      final aww = AWWModel(
        awwId: awwId,
        name: awwId,
        mobileNumber: '', // No phone number field
        awcCode: 'AWW_DEMO_001',
        mandal: _mandal ?? '',
        district: _district ?? '',
        password: 'google_oauth_token',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final payload = {
        'aww_id': aww.awwId,
        'name': aww.name,
        'mobile_number': aww.mobileNumber,
        'password': aww.password,
        'awc_code': aww.awcCode,
        'mandal': aww.mandal,
        'district': aww.district,
        'created_at': aww.createdAt.toIso8601String(),
        'updated_at': aww.updatedAt.toIso8601String(),
      };
      try {
        await _apiService.registerAWW(payload);
      } catch (apiError) {
        setState(() => _loading = false);
        if (!mounted) return;
        final message = apiError.toString().toLowerCase();
        if (message.contains('http 409') ||
            message.contains('already registered')) {
          await _showAlreadyRegisteredDialog();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $apiError')),
        );
        return;
      }

      final ok = await _auth.register(aww);
      setState(() => _loading = false);
      if (!mounted) return;
      
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('registration_success'))));
        // Return to Login screen and indicate this registration used Google
        Navigator.of(context).pop({
          'mobile': awwId,
          'name': awwId,
          'google': 'true',
          'awc_code': 'AWW_DEMO_001',
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('error_invalid_login'))));
      }
    } on Exception catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      
      // Handle plugin exceptions gracefully
      final errorMsg = e.toString();
      if (errorMsg.contains('MissingPluginException') || errorMsg.contains('No implementation found')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.t('google_signin_not_configured')),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.t('google_signin_error')}: $errorMsg')));
      }
    }
  }

  Future<void> _register() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final password = _passwordController.text;
    final awc = _awcController.text.trim().toUpperCase();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final awwId = 'aww_$timestamp'; // Generate unique ID using timestamp

    final aww = AWWModel(
      awwId: awwId,
      name: awwId, // Use awwId as name since name field is removed
      mobileNumber: '', // Empty since mobile field is removed
      awcCode: awc.isEmpty ? 'AWW_DEMO_001' : awc,
      mandal: _mandal ?? '',
      district: _district ?? '',
      password: password,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      // First, register in backend (source of truth) and prevent duplicates.
      final payload = {
        'aww_id': aww.awwId,
        'name': aww.name,
        'mobile_number': aww.mobileNumber,
        'password': aww.password,
        'awc_code': aww.awcCode,
        'mandal': aww.mandal,
        'district': aww.district,
        'created_at': aww.createdAt.toIso8601String(),
        'updated_at': aww.updatedAt.toIso8601String(),
      };
      try {
        await _apiService.registerAWW(payload);
      } catch (apiError) {
        setState(() => _loading = false);
        if (!mounted) return;
        final message = apiError.toString().toLowerCase();
        if (message.contains('http 409') ||
            message.contains('already registered')) {
          await _showAlreadyRegisteredDialog();
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registration failed: $apiError')),
        );
        return;
      }

      // Then, save locally.
      final ok = await _auth.register(aww);
      if (!ok) {
        setState(() => _loading = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.t('error_invalid_login'))),
        );
        return;
      }

      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('registration_success'))));
      // Return to Login screen and indicate a normal registration completed
      Navigator.of(context).pop({
        'mobile': awwId,
        'name': awwId,
        'registered': 'true',
        'awc_code': aww.awcCode,
      });
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.t('error_invalid_login')}: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.42,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      const LanguageMenuButton(iconColor: Colors.white),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipOval(
                    child: Image.asset(
                      'assets/images/ap_logo.png',
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFF2E7D32), width: 2),
                        ),
                        child: Center(
                          child: Text(
                            l10n.t('ap_short'),
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppLocalizations.of(context).t('govt_andhra_pradesh'),
                    style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context).t('app_full_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextFormField(
                                  controller: _awcController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: InputDecoration(prefixIcon: const Icon(Icons.home_outlined), hintText: l10n.t('awc_code')),
                                  validator: (value) {
                                    final awc = (value ?? '').trim().toUpperCase();
                                    if (awc.isEmpty) {
                                      return l10n.t('awc_code');
                                    }
                                    if (!_awcCodePattern.hasMatch(awc)) {
                                      return 'Use format AWW_DEMO_001';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _district,
                                  items: _districts
                                      .map(
                                        (d) => DropdownMenuItem<String>(
                                          value: d,
                                          child: Text(d),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _district = value;
                                      _mandal = null;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.location_city),
                                    hintText: l10n.t('select_district'),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? l10n.t('select_district')
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  initialValue: _mandal,
                                  items: _mandalsForDistrict
                                      .map(
                                        (m) => DropdownMenuItem<String>(
                                          value: m,
                                          child: Text(m),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _district == null
                                      ? null
                                      : (value) {
                                          setState(() => _mandal = value);
                                        },
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.map_outlined),
                                    hintText: l10n.t('select_mandal'),
                                  ),
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? l10n.t('select_mandal')
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock),
                                    hintText: l10n.t('password'),
                                    suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)),
                                  ),
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return l10n.t('error_password_required');
                                    if (v.length < AppConstants.minPasswordLength) return l10n.t('password_min_length', {'count': '${AppConstants.minPasswordLength}'});
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _confirmController,
                                  obscureText: true,
                                  decoration: InputDecoration(prefixIcon: const Icon(Icons.lock_outline), hintText: l10n.t('confirm_password')),
                                  validator: (v) => (v != _passwordController.text) ? l10n.t('confirm_password_mismatch') : null,
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _register,
                                    child: Text(_loading ? l10n.t('registering') : l10n.t('sign_up').toUpperCase()),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: _loading ? null : _registerWithGoogle,
                                  icon: const Icon(Icons.login),
                                  label: Text(l10n.t('sign_in_with_google')),
                                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                ),
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(l10n.t('login')),
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
