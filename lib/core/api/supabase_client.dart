// lib/core/api/supabase_client.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Global Supabase client accessor
/// Use: SupabaseService.client.from('cases')...
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static GoTrueClient get auth => Supabase.instance.client.auth;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      debug: false,
    );
  }

  /// Current authenticated user
  static User? get currentUser => client.auth.currentUser;

  /// Current user ID (throws if not authenticated)
  static String get userId {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  /// Sign in with email and password
  static Future<AuthResponse> signIn(String email, String password) async {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Upload a file to Supabase Storage
  /// Returns the public URL path
  static Future<String> uploadFile({
    required String bucket,
    required String path,
    required List<int> bytes,
    required String mimeType,
  }) async {
    await client.storage.from(bucket).uploadBinary(
      path,
      Uint8List.fromList(bytes),
      fileOptions: FileOptions(contentType: mimeType, upsert: true),
    );
    return path;
  }

  /// Get a signed URL for a private file (1 hour expiry)
  static Future<String> getSignedUrl(String bucket, String path) async {
    final response = await client.storage
        .from(bucket)
        .createSignedUrl(path, 3600);
    return response;
  }
}
