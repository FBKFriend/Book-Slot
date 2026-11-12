import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

void main() => runApp(const BookSlotApp());

class BookSlotApp extends StatelessWidget {
  const BookSlotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOOKSLOT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const ThemeTestScreen(),
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
