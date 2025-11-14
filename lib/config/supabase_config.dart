import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static late SupabaseClient supabaseClient;

  static Future<void> initialize() async {
    // Carregar variáveis de ambiente
    await dotenv.load();

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseKey == null) {
      throw Exception('Variáveis de ambiente não configuradas!');
    }

    // Inicializar Supabase
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
    );

    supabaseClient = Supabase.instance.client;
  }

  static SupabaseClient get client => supabaseClient;
  static String get userId => supabaseClient.auth.currentUser?.id ?? '';
  static bool get isAuthenticated => supabaseClient.auth.currentUser != null;
}