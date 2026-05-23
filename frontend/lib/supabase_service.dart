import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  // 2. The factory constructor MUST match the class name and return the instance
  factory SupabaseService() => _instance;

  // 3. The private named constructor
  SupabaseService._internal();

  // Replace with your local network IP if testing on a physical device, or use 10.0.2.2 for Android Emulator
  final String backendBaseUrl = 'http://localhost:8000';

  Future<void> initialize() async {
    await Supabase.initialize(
    url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'http://127.0.0.1:8000', // Falls back to local container testing
      ),
    anonKey: const String.fromEnvironment(
        'SUPABASE_KEY',
    )
    );
  }

  SupabaseClient get client => Supabase.instance.client;
  
  // Quick helper to fetch the current authenticated user's ID
  String? get currentUserId => client.auth.currentUser?.id;
}

final supabaseService = SupabaseService();