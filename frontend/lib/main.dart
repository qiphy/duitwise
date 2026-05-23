import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'supabase_service.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';

// 🎯 The single source of truth for global app routing and modal overlays
final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // Initialize internal hardware framework hook mechanisms securely
  WidgetsFlutterBinding.ensureInitialized();
  
  // ⚡ Initialize Firebase Cloud Messaging core native background bindings
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize Supabase core connection vectors safely
  await supabaseService.initialize();

  // 🛠️ FIX: Removed the dead parameterless notification initialization from here.
  // The pipeline is now triggered cleanly inside HomeScreen's lifecycle.

  final rawToken = await FirebaseMessaging.instance.getToken();
  debugPrint('🚨 EARLY BOOT TOKEN CHECK: $rawToken');
  
  runApp(const FinancialLiteracyApp());
}

class FinancialLiteracyApp extends StatelessWidget {
  const FinancialLiteracyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check dynamically if a user profile is already stored on disk
    final currentSession = supabaseService.client.auth.currentSession;

    return MaterialApp(
      title: 'Financial Literacy for Kids',
      debugShowCheckedModeBanner: false,
      navigatorKey: globalNavigatorKey, // Registered globally to allow context-free modal injections
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8B5CF6),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        fontFamily: 'SF Pro Display',
      ),
      // Set your highly polished, animated splash screen as the root node entry point
      home: const SplashScreen(),
    );
  }
}