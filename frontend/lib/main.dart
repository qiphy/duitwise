import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase bindings safely before bootstrapping the UI layer
  await supabaseService.initialize();
  
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
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8B5CF6),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        fontFamily: 'SF Pro Display',
      ),
      //  UPDATED: Set your highly polished, animated splash screen as the root node entry point
      home: const SplashScreen(),
    );
  }
}