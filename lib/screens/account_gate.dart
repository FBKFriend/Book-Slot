import 'superadmin/superadmin_shell.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';

class AccountGate extends StatefulWidget {
  final User user;
  const AccountGate({super.key, required this.user});

  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  late final Stream<AppUser?> _stream;

  @override
  void initState() {
    super.initState();
    _stream = UserService.instance.watchUser(widget.user.email ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const StatusScreen(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: 'Could not load your account. Check your connection and try again.',
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final me = snap.data;
        if (me == null) {
          return StatusScreen(
            icon: Icons.person_off_outlined,
            title: 'No account found',
            message:
                '${widget.user.email} is not registered yet. Sign up as a student first, or ask the administrator to add your account.',
          );
        }
        switch (me.status) {
          case 'active':
            return me.role == 'superadmin'
                ? SuperAdminShell(user: me)
                : RoleHomePlaceholder(user: me);
          case 'suspended':
            return const StatusScreen(
              icon: Icons.block,
              title: 'Account suspended',
              message: 'Please contact the library administrator.',
            );
          default:
            return const StatusScreen(
              icon: Icons.hourglass_top,
              title: 'Waiting for approval',
              message: 'Your registration is being reviewed by the administrator. This screen updates by itself once you are approved.',
            );
        }
      },
    );
  }
}

class StatusScreen extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  const StatusScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: AppColors.gold),
              const SizedBox(height: 20),
              Text(title, style: t.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(message, style: t.bodyMedium, textAlign: TextAlign.center),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => AuthService.instance.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleHomePlaceholder extends StatelessWidget {
  final AppUser user;
  const RoleHomePlaceholder({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('${user.role} home')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name.isEmpty ? user.email : user.name,
              style: t.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text('Role: ${user.role}', style: t.bodyMedium),
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
