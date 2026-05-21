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
      url: 'https://tbrefzeytkflqyadayvs.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRicmVmemV5dGtmbHF5YWRheXZzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkzMzAyNDIsImV4cCI6MjA5NDkwNjI0Mn0.n48ovgMT-jbPgKOtBcfgmr7M_0HktWon6Djjn6BkD6g',
    );
  }

  SupabaseClient get client => Supabase.instance.client;
  
  // Quick helper to fetch the current authenticated user's ID
  String? get currentUserId => client.auth.currentUser?.id;
}

final supabaseService = SupabaseService();