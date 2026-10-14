import 'package:flutter/material.dart';

import 'auth.dart';
import 'l10n/app_localizations.dart';
import 'market.dart';
import 'state.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  String _errorText(AppLocalizations l10n, String? code) {
    switch (code) {
      case 'phone_invalid':
        return l10n.authPhoneInvalid;
      case 'code_invalid':
        return l10n.authCodeInvalid;
      case 'handle_empty':
        return l10n.authHandleEmpty;
      case 'provider_unconfigured':
        return l10n.authProviderUnconfigured;
      case 'sms_unconfigured':
        return l10n.authSmsUnconfigured;
      case 'email_invalid':
        return l10n.authEmailInvalid;
      case 'password_short':
        return l10n.authPasswordShort;
      case 'email_taken':
        return l10n.authEmailTaken;
      case 'credentials_invalid':
        return l10n.authCredentialsInvalid;
      case 'failed':
        return l10n.authFailed;
      default:
        return l10n.authFailed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ChowScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: [
                Text(
                  MarketConfig.brand,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFB42318),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.bornInCambodia, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  AuthConfig.apiLive
                      ? l10n.authLiveBanner
                      : l10n.authMockBanner,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (state.authLoading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (state.authError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorText(l10n, state.authError),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF8B1E1E)),
                    ),
                  ),
                FilledButton(
                  key: const Key('sign_in_google'),
                  onPressed: state.authLoading
                      ? null
                      : () => state.signIn(
                          method: 'google',
                          handle: 'sokha@chow.app',
                        ),
                  child: Text(
                    AuthConfig.googleLive
                        ? l10n.authGoogleLive
                        : l10n.authGoogle,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('sign_in_facebook'),
                  onPressed: state.authLoading
                      ? null
                      : () => state.signIn(
                          method: 'facebook',
                          handle: 'sokha.fb@chow.app',
                        ),
                  child: Text(
                    AuthConfig.facebookLive
                        ? l10n.authFacebookLive
                        : l10n.authFacebook,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  key: const Key('sign_in_wechat'),
                  onPressed: state.authLoading
                      ? null
                      : () => state.signIn(
                          method: 'wechat',
                          handle: 'sokha.wx@chow.app',
                        ),
                  child: Text(
                    AuthConfig.wechatLive
                        ? l10n.authWechatLive
                        : l10n.authWechat,
                  ),
                ),
                const SizedBox(height: 20),
                Text(_register ? l10n.authCreateAccount : l10n.authEmailLabel),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('sign_in_email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: l10n.authEmailHint,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('sign_in_email_password'),
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: l10n.authPasswordHint,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (_register) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      hintText: l10n.authNameHint,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('sign_in_email_submit'),
                  onPressed: state.authLoading
                      ? null
                      : () => state.signIn(
                          method: 'email',
                          handle: _email.text,
                          password: _password.text,
                          name: _name.text,
                          register: _register,
                        ),
                  child: Text(
                    _register ? l10n.authCreateAccount : l10n.authEmailSignIn,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: state.authLoading
                        ? null
                        : () => setState(() => _register = !_register),
                    child: Text(
                      _register ? l10n.authHaveAccount : l10n.authNeedAccount,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(l10n.authPhoneLabel),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('sign_in_phone_number'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: l10n.authPhoneHint,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                if (state.phoneCodeSent) ...[
                  if (state.devCode != null) ...[
                    const SizedBox(height: 10),
                    Text('${l10n.authDevCode} ${state.devCode}'),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('sign_in_phone_code'),
                    controller: _code,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: l10n.authCodeHint,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                FilledButton.tonal(
                  key: const Key('sign_in_phone'),
                  onPressed: state.authLoading
                      ? null
                      : () => state.signIn(
                          method: 'phone',
                          handle: _phone.text,
                          code: _code.text,
                        ),
                  child: Text(
                    state.phoneCodeSent ? l10n.authVerify : l10n.authSendCode,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: state.toggleLocale,
                    child: Text(l10n.languageToggle),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
