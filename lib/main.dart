import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  debugPrint('Firebase connected: ${Firebase.app().options.projectId}');
  runApp(const BookSlotApp());
}

class BookSlotApp extends StatelessWidget {
  const BookSlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOOKSLOT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(next: AuthGate()),
    );
  }
}

class ThemeTestScreen extends StatelessWidget {
  const ThemeTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('BOOKSLOT')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Granby Library', style: t.headlineMedium),
            const SizedBox(height: 8),
            Text('Body text in Inter', style: t.bodyMedium),
            Text('Muted subtitle', style: t.bodySmall),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('This is a card'),
              ),
            ),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(hintText: 'Input')),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: () {}, child: const Text('Primary')),
          ],
        ),
      ),
    );
  }
}
