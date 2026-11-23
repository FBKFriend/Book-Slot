import 'package:flutter/material.dart';

import '../../data/legal_text.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/legal_checkbox.dart';
import '../../widgets/legal_dialog.dart';

class LegalAcceptScreen extends StatefulWidget {
  final AppUser user;
  const LegalAcceptScreen({super.key, required this.user});

  @override
  State<LegalAcceptScreen> createState() => _LegalAcceptScreenState();
}

class _LegalAcceptScreenState extends State<LegalAcceptScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UserService.instance.acceptLegal(
        widget.user.email,
        terms: true,
        privacy: true,
      );
      // The account gate sees the change and opens the app by itself
    } catch (e) {
      debugPrint('accept legal failed: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(28),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.policy_outlined, size: 56, color: AppColors.gold),
            const SizedBox(height: 20),
            Text(
              'Accept to continue',
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'You withdrew your agreement earlier. To keep using BookSlot, please read and accept the Terms of Service and the Privacy Policy again.',
              style: t.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            LegalCheckbox(
              value: _terms,
              onChanged: _saving ? null : (v) => setState(() => _terms = v),
              leading: 'I agree to the ',
              linkText: 'Terms of Service',
              onOpen: () => showLegalDialog(context, kTermsOfService),
            ),
            LegalCheckbox(
              value: _privacy,
              onChanged: _saving ? null : (v) => setState(() => _privacy = v),
              leading: 'I have read the ',
              linkText: 'Privacy Policy',
              trailing: ' and consent to the handling of my personal data.',
              onOpen: () => showLegalDialog(context, kPrivacyPolicy),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE57373)),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: (_saving || !_terms || !_privacy) ? null : _accept,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Accept and continue'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving ? null : () => AuthService.instance.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
