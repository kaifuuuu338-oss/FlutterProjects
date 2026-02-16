import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/screens/dashboard_screen.dart';
import 'package:my_first_app/services/api_service.dart';
import 'package:my_first_app/services/auth_service.dart';
import 'package:my_first_app/screens/signup_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:my_first_app/widgets/language_menu_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  final APIService _apiService = APIService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool _googleRegistered = false;
  bool _passwordDisabled = false;

  bool _loading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    bool success = false;
    try {
      final token = await _apiService.login(
        _mobileController.text.trim(),
        _passwordController.text,
      );
      await _authService.saveToken(token);
      success = true;
    } catch (_) {
      // Fallback for offline/demo mode so field testing can continue.
      success = await _authService.login(
        _mobileController.text.trim(),
        _passwordController.text,
      );
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (!success) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('error_invalid_login'))),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  Future<void> _loginWithGoogle() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() => _loading = false);
        return; // User cancelled the sign-in
      }
      
      // Generate a token from Google account (or mock for demo)
      final token = 'google_${account.id}_${DateTime.now().millisecondsSinceEpoch}';
      await _authService.saveToken(token);
      
      // Pre-fill with Google account name for reference
      _mobileController.text = account.email;
      
      if (!mounted) return;
      setState(() => _loading = false);
      
      // Navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.t('google_signin_error')}: $errorMsg')),
        );
      }
    }
  }

  Future<void> _loginRegistered() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final authed = await _authService.isAuthenticated();
      if (!mounted) return;
      setState(() => _loading = false);
      if (authed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.t('error_invalid_login'))),
      );
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.t('error_invalid_login')}: $e')),
      );
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
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 16),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.t('please_enter_details'),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  l10n.t('welcome_back'),
                                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 14),

                                // Username / Mobile field
                                TextFormField(
                                  controller: _mobileController,
                                  keyboardType: TextInputType.text,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.person),
                                    hintText: l10n.t('username_or_mobile'),
                                  ),
                                  validator: (v) {
                                    final value = (v ?? '').trim();
                                    if (value.isEmpty) return l10n.t('error_username_or_mobile_required');
                                    // accept either 10-digit mobile OR any non-empty username
                                    if (value.length == 10 && int.tryParse(value) != null) return null;
                                    if (value.length >= 2) return null;
                                    return l10n.t('error_username_or_mobile_required');
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Password field (hidden if user registered via Google or returned from signup)
                                if (!(_googleRegistered || _passwordDisabled))
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.lock),
                                      hintText: l10n.t('password'),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                    ),
                                    validator: (v) => (v == null || v.isEmpty) ? l10n.t('error_password_required') : null,
                                  ),
                                const SizedBox(height: 12),

                                // Remember + Forgot row
                                Row(
                                  children: [
                                    Checkbox(
                                      value: (_rememberMe ?? false),
                                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                    ),
                                    Expanded(child: Text(l10n.t('remember_for_30_days'))),
                                    TextButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(l10n.t('contact_supervisor_reset'))),
                                        );
                                      },
                                      child: Text(l10n.t('forgot_password')),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Primary CTA (matches example image label)
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading
                                        ? null
                                        : (_googleRegistered
                                            ? _loginWithGoogle
                                            : (_passwordDisabled ? _loginRegistered : _login)),
                                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                                    child: Text(_loading ? l10n.t('logging_in') : l10n.t('login').toUpperCase()),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Social / Google placeholder
                                OutlinedButton.icon(
                                  onPressed: _loading ? null : _loginWithGoogle,
                                  icon: const Icon(Icons.login),
                                  label: Text(l10n.t('sign_in_with_google')),
                                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                                ),
                                const SizedBox(height: 12),

                                // Footer small
                                Center(
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(l10n.t('dont_have_account')),
                                      TextButton(
                                        onPressed: () async {
                                          final result = await Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(builder: (_) => const SignUpScreen()));
                                          if (result != null && mounted) {
                                            final mobile = result['mobile'] ?? '';
                                            final name = result['name'] ?? '';
                                              final googleFlag = result['google'] ?? '';
                                              final registeredFlag = result['registered'] ?? '';
                                            if (mobile.isNotEmpty) {
                                              _mobileController.text = mobile;
                                            }
                                              if (googleFlag == 'true') {
                                                // Hide password field and switch Login button to perform Google sign-in
                                                setState(() {
                                                  _googleRegistered = true;
                                                  _passwordDisabled = false;
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('${l10n.t('registration_success')} - ${l10n.t('welcome_back')}, $name!')),
                                                );
                                              } else if (registeredFlag == 'true') {
                                                // Regular signup: password is disabled (user must login via saved token)
                                                setState(() {
                                                  _passwordDisabled = true;
                                                  _googleRegistered = false;
                                                });
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('${l10n.t('registration_success')} - ${l10n.t('welcome_back')}, $name!')),
                                                );
                                              } else {
                                                if (name.isNotEmpty) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('${l10n.t('registration_success')} - ${l10n.t('welcome_back')}, $name!')),
                                                  );
                                                }
                                              }
                                          }
                                        },
                                        child: Text(l10n.t('sign_up')),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    l10n.t('help_line_with_number', {'number': '9000-355-3220'}),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
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
