import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'supabase_service.dart';
import 'screens/splash_screen.dart';
import 'firebase_options.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:camera/camera.dart'; // 💡 1. Import Camera Package

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

// 💡 2. Global source of truth for device lenses
List<CameraDescription> appSystemCameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    debugPrint('🌐 Production Web Target Detected.');
    await supabaseService.initialize();
  } else {
    debugPrint('📱 Native Mobile Target Detected.');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await supabaseService.initialize();

    // 💡 3. Quick-scan hardware lenses concurrently during application boot
    try {
      appSystemCameras = await availableCameras();
    } catch (e) {
      debugPrint('No physical cameras found: $e');
    }

    try {
      final rawToken = await FirebaseMessaging.instance.getToken();
      debugPrint('🚨 EARLY BOOT TOKEN CHECK: $rawToken');
    } catch (e) {
      debugPrint('Token error: $e');
    }
  }
  runApp(const FinancialLiteracyApp());
}

class FinancialLiteracyApp extends StatelessWidget {
  const FinancialLiteracyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duitwise | Financial Literacy for Kids',
      debugShowCheckedModeBanner: false,
      navigatorKey: globalNavigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8B5CF6),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        fontFamily: 'SF Pro Display',
      ),
      home: const SplashScreen(),
    );
  }
}