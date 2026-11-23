import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/legal_text.dart';
import '../widgets/legal_checkbox.dart';
import '../widgets/legal_dialog.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

String? _required(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _signingIn = false;
  String? _signInError;

  Future<void> _google() async {
    setState(() {
      _signingIn = true;
      _signInError = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      debugPrint('Sign-up sign-in error: $e');
      if (!mounted) return;
      setState(() => _signInError = 'Sign-in failed. Please try again.');
    }
    if (mounted) setState(() => _signingIn = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Student sign up')),
      body: StreamBuilder<User?>(
        stream: AuthService.instance.authChanges,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snap.data;
          if (user != null) {
            return _RegistrationStep(key: ValueKey(user.uid), user: user);
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 24),
              Text('Create your account', style: t.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Step 1: sign in with the Google account you want to use in BOOKSLOT.\nStep 2: fill in your student information.',
                style: t.bodySmall,
              ),
              const SizedBox(height: 28),
              _GoogleButton(loading: _signingIn, onTap: _google),
              if (_signInError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _signInError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE57373)),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF131314),
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFF8E918F))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.gold,
                  ),
                )
              else ...[
                SvgPicture.asset('assets/google_g.svg', width: 20, height: 20),
                const SizedBox(width: 10),
                Text(
                  'Continue with Google',
                  style: GoogleFonts.roboto(
                    color: const Color(0xFFE3E3E3),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationStep extends StatefulWidget {
  final User user;
  const _RegistrationStep({super.key, required this.user});

  @override
  State<_RegistrationStep> createState() => _RegistrationStepState();
}

class _RegistrationStepState extends State<_RegistrationStep> {
  late final String _email = (widget.user.email ?? '').toLowerCase();
  late final Stream<AppUser?> _stream = UserService.instance.watchUser(_email);

  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  final _idDigits = TextEditingController();
  final _age = TextEditingController();
  final _course = TextEditingController();
  String? _sex;
  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _saving = false;
  bool _justSubmitted = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    _idDigits.dispose();
    _age.dispose();
    _course.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms || !_acceptPrivacy) return;
    if (_sex == null) {
      setState(() => _error = 'Please select your sex.');
      return;
    }
    // Set before saving, so the "sent" message shows (not "already
    // registered") the moment the new record appears
    setState(() {
      _saving = true;
      _justSubmitted = true;
      _error = null;
    });
    try {
      await UserService.instance.registerStudent(
        email: _email,
        first: _first.text,
        middle: _middle.text,
        last: _last.text,
        studentId: 'GC-${_idDigits.text}',
        age: int.parse(_age.text),
        sex: _sex!,
        course: _course.text,
      );
    } on AccountExistsException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _justSubmitted = false;
        _error = 'This account is already registered.';
      });
    } catch (e) {
      debugPrint('Sign up failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _justSubmitted = false;
        _error = 'Could not submit your registration. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Could not check your account. Check your connection and try again.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.data != null) {
          return _DoneMessage(justSubmitted: _justSubmitted);
        }
        return _form(context);
      },
    );
  }

  Widget _form(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Signed in with Google', style: t.bodySmall),
                      Text(
                        _email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => AuthService.instance.signOut(),
                  child: const Text('Change'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Your information', style: t.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Fill in everything. The administrator will check it before approving your account.',
          style: t.bodySmall,
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _first,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'First name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _middle,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Middle name (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _last,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Last name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _idDigits,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  labelText: 'Student ID',
                  prefixText: 'GC-',
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                ),
                validator: (v) =>
                    (v ?? '').length == 6 ? null : 'Enter the 6 digits',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return (n != null && n >= 10 && n <= 99)
                      ? null
                      : 'Enter a valid age';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _course,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Course',
                  hintText: 'e.g. BSIT',
                ),
                validator: _required,
              ),
              const SizedBox(height: 14),
              Text('Sex', style: t.bodySmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in const ['Male', 'Female'])
                    ChoiceChip(
                      label: Text(s),
                      selected: _sex == s,
                      selectedColor: AppColors.gold.withValues(alpha: 0.2),
                      onSelected: (_) => setState(() => _sex = s),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LegalCheckbox(
          value: _acceptTerms,
          onChanged: _saving ? null : (v) => setState(() => _acceptTerms = v),
          leading: 'I agree to the ',
          linkText: 'Terms of Service',
          onOpen: () => showLegalDialog(context, kTermsOfService),
        ),
        LegalCheckbox(
          value: _acceptPrivacy,
          onChanged: _saving ? null : (v) => setState(() => _acceptPrivacy = v),
          leading: 'I have read the ',
          linkText: 'Privacy Policy',
          trailing: ' and consent to the handling of my personal data.',
          onOpen: () => showLegalDialog(context, kPrivacyPolicy),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFE57373))),
        ],
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: (_saving || !_acceptTerms || !_acceptPrivacy)
              ? null
              : _submit,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit registration'),
        ),
      ],
    );
  }
}

class _DoneMessage extends StatelessWidget {
  final bool justSubmitted;
  const _DoneMessage({required this.justSubmitted});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              justSubmitted ? Icons.check_circle_outline : Icons.info_outline,
              size: 64,
              color: AppColors.gold,
            ),
            const SizedBox(height: 20),
            Text(
              justSubmitted ? 'Registration sent' : 'Already registered',
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              justSubmitted
                  ? 'The library administrator will review your registration. Close this page and wait for approval. The next screen updates by itself once you are approved.'
                  : 'This Google account is already registered. Close this page to continue.',
              style: t.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
