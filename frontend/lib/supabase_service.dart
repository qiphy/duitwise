import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() => _instance;

  SupabaseService._internal();

  // Live Server Production Domains
  final String backendBaseUrl = 'https://api.duitwise.app';
  final String frontendUrl = 'https://duitwise.app';

  // Local storage cache keys for tracking your custom session state
  String? _customUserId;
  String? _sessionToken;

  Future<void> initialize() async {
    // Keep the core initialization alive for standard public table query pipelines if needed
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://api.duitwise.app', 
      ),
      anonKey: const String.fromEnvironment(
        'SUPABASE_KEY',
      ),
    );
  }

  SupabaseClient get client => Supabase.instance.client;
  
  // Expose the authenticated state globally across your Flutter view controllers
  String? get currentUserId => _customUserId ?? client.auth.currentUser?.id;
  String? get sessionToken => _sessionToken;

  /// Custom high-signal authentication terminal interacting directly with your FastAPI server container
  Future<bool> loginWithFastAPI(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/api/v1/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Cache session context attributes locally
        _customUserId = data['user_id'];
        _sessionToken = data['session_token'];
        
        return true; 
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Authentication rejected.');
      }
    } catch (e) {
      print('DuitWise Auth Service Exception: $e');
      rethrow;
    }
  }

  /// Reset internal state vectors on logout
  void clearSession() {
    _customUserId = null;
    _sessionToken = null;
  }
}

final supabaseService = SupabaseService();