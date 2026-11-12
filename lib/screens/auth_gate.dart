import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: SizedBox.shrink());
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();
        return SignedInPlaceholder(user: user);
      },
    );
  }
}

class SignedInPlaceholder extends StatelessWidget {
  final User user;
  const SignedInPlaceholder({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Signed in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.displayName ?? 'No name', style: t.headlineMedium),
            const SizedBox(height: 6),
            Text(user.email ?? 'No email', style: t.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => AuthService.instance.signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
