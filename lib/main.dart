import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // NEW: Import Auth
import 'firebase_options.dart'; 
import 'core/theme/app_theme.dart';
import 'features/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // NEW: The Invisible Login
  // If the user doesn't have an account yet, silently create one in the background.
  if (FirebaseAuth.instance.currentUser == null) {
    await FirebaseAuth.instance.signInAnonymously();
  }

  runApp(
    const ProviderScope(
      child: FitMeApp(),
    ),
  );
}

class FitMeApp extends StatelessWidget {
  const FitMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitMe',
      theme: ThemeData(
        scaffoldBackgroundColor: AppTheme.background,
        colorScheme: const ColorScheme.dark(
          primary: AppTheme.accent,
          surface: AppTheme.surface,
          background: AppTheme.background,
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}