import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import '../models/connection_model.dart';
import 'local_storage.dart';

class SupabaseManager {
  static SupabaseClient? _client;
  static String? _currentUrl;

  static SupabaseClient get client {
    if (_client == null) throw Exception('Supabase not initialized');
    return _client!;
  }

  static bool get isInitialized => _client != null;

  static bool get hasActiveSession {
    if (!isInitialized) return false;
    return _client!.auth.currentSession != null;
  }

  /// MAIN INITIALIZATION (used when user selects a connection)
  static Future<void> initialize(ConnectionModel conn) async {
    await _init(conn.url, conn.anonKey);
    await LocalStorage.saveLastConnection(conn);
  }

  /// Restore last used connection silently on app start
  static Future<bool> restoreLastConnection() async {
    final conn = await LocalStorage.loadLastConnection();
    if (conn == null) return false;
    try {
      await _init(conn.url, conn.anonKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _init(String url, String anonKey) async {
    // If already initialized to the same URL, reuse the existing instance
    if (_client != null && _currentUrl == url) return;

    // If Supabase was initialized to a different URL, dispose it first
    try {
      await Supabase.instance.dispose();
    } catch (_) {
      // Not yet initialized — that's fine
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    _client = Supabase.instance.client;
    _currentUrl = url;
  }

  /// LIGHTWEIGHT HEALTH CHECK (for grid status dot)
  /// Uses a temporary isolated client — does NOT affect the global instance
  static Future<bool> testConnection(ConnectionModel conn) async {
    try {
      final temp = SupabaseClient(conn.url, conn.anonKey);
      await temp
          .from('app_meta')
          .select('id')
          .limit(1)
          .maybeSingle();
      await temp.dispose();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// SIGN OUT
  static Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {}
    _client = null;
    _currentUrl = null;
    await LocalStorage.clearLastConnection();
  }

  /// TABLE CHECK
  static Future<bool> checkTables() async {
    if (!isInitialized) return false;
    const requiredTables = [
      'app_meta',
      'audit_log',
      'equipment',
      'fishlines',
      'messages',
      'protocols',
      'reagents',
      'requested_strains',
      'reservations',
      'samples',
      'storage_locations',
      'strains',
      'users',
      'zebrafish_facility',
    ];
    try {
      final res = await client
          .from('information_schema.tables')
          .select('table_name')
          .eq('table_schema', 'public');
      final existing =
          (res as List).map((e) => e['table_name'] as String).toSet();
      return requiredTables.every(existing.contains);
    } catch (_) {
      return false;
    }
  }

  /// SUPERADMIN CHECK
  static Future<bool> adminExists() async {
    if (!isInitialized) return false;
    try {
      final res = await client
          .from('users')
          .select('id')
          .eq('role', 'superadmin')
          .limit(1);
      return (res as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkTablesDirectly(List<String> tables) async {
    try {
      for (final table in tables) {
        await client.from(table).select('*').limit(1);
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}