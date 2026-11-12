import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithGoogle();
    } catch (e) {
      debugPrint('Sign-in error: $e');
      if (!mounted) return;
      setState(() => _error = 'Sign-in failed. Please try again.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _googleButton() {
    return Material(
      color: const Color(0xFF131314),
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFF8E918F))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _loading ? null : _signIn,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading)
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
                  'Sign in with Google',
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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),
              SvgPicture.asset('assets/logo.svg', width: 96, height: 96),
              const SizedBox(height: 16),
              Text(
                'BOOKSLOT',
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.heading,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Granby Colleges Mobile Library System',
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              const Spacer(flex: 4),
              _googleButton(),
              const SizedBox(height: 14),
              Text(
                'Only authorized Granby accounts can sign in',
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE57373)),
                ),
              ],
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
