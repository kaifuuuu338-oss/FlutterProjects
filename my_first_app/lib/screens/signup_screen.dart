import 'package:flutter/material.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/constants/app_constants.dart';
import 'package:my_first_app/models/aww_model.dart';
import 'package:my_first_app/services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class SignUpScreen extends StatefulWidget {
  final String? initialName;
  const SignUpScreen({super.key, this.initialName});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _awcController = TextEditingController(text: 'AWS_DEMO_001');

  final AuthService _auth = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _awcController.dispose();
    super.dispose();
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
      final aww = AWWModel(
        awwId: 'aww_${account.email.replaceAll('@', '_')}',
        name: account.displayName ?? account.email,
        mobileNumber: '9999999999', // Demo placeholder for Google sign-up
        awcCode: 'AWS_DEMO_001',
        mandal: '',
        district: '',
        password: 'google_oauth_token',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final ok = await _auth.register(aww);
      setState(() => _loading = false);
      if (!mounted) return;
      
      if (ok) {
        final name = account.displayName ?? account.email;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('registration_success'))));
        // Return to Login screen and indicate this registration used Google
        Navigator.of(context).pop({'mobile': account.email, 'name': name, 'google': 'true'});
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

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final password = _passwordController.text;
    final awc = _awcController.text.trim();

    final aww = AWWModel(
      awwId: 'aww_$mobile',
      name: name,
      mobileNumber: mobile,
      awcCode: awc.isEmpty ? 'AWS_DEMO_001' : awc,
      mandal: '',
      district: '',
      password: password,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final ok = await _auth.register(aww);
      setState(() => _loading = false);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('registration_success'))));
        // Return to Login screen and indicate a normal registration completed
        Navigator.of(context).pop({'mobile': mobile, 'name': name, 'registered': 'true'});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.t('error_invalid_login'))));
      }
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
                                  controller: _nameController,
                                  decoration: InputDecoration(prefixIcon: const Icon(Icons.person), hintText: l10n.t('full_name')),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? '${l10n.t('full_name')} ${l10n.t('is_required')}' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _mobileController,
                                  keyboardType: TextInputType.phone,
                                  maxLength: 10,
                                  decoration: InputDecoration(prefixIcon: const Icon(Icons.phone), hintText: l10n.t('mobile_number')),
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.length != 10) return l10n.t('error_mobile_10');
                                    if (int.tryParse(value) == null) return l10n.t('error_numbers_only');
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _awcController,
                                  decoration: InputDecoration(prefixIcon: const Icon(Icons.home_outlined), hintText: l10n.t('awc_code')),
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
