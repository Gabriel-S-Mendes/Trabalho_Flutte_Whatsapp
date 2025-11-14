import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';

class AuthService {
  final _supabase = SupabaseConfig.client;

  // Verificar se usuário está autenticado
  bool get isAuthenticated => SupabaseConfig.isAuthenticated;

  // Obter usuário atual
  User? get currentUser => _supabase.auth.currentUser;

  // SIGNUP - Cadastro
  Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Criar usuário no Auth
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Erro ao criar usuário');
      }

      // Criar perfil do usuário na tabela 'users'
      await _supabase.from('users').insert({
        'id': response.user!.id,
        'email': email,
        'full_name': fullName,
        'is_online': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return {'success': true, 'user': response.user};
    } on AuthException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // LOGIN - Fazer login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Erro ao fazer login');
      }

      // Atualizar status online
      await _supabase.from('users').update({
        'is_online': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', response.user!.id);

      return {'success': true, 'user': response.user};
    } on AuthException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // LOGOUT - Fazer logout
  Future<Map<String, dynamic>> logout() async {
    try {
      // Atualizar status offline
      if (currentUser != null) {
        await _supabase.from('users').update({
          'is_online': false,
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('id', currentUser!.id);
      }

      await _supabase.auth.signOut();
      return {'success': true};
    } on AuthException catch (e) {
      return {'success': false, 'error': e.message};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Obter dados do usuário
  Future<UserModel?> getUser(String userId) async {
    try {
      final response =
          await _supabase.from('users').select().eq('id', userId).single();
      return UserModel.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  // Atualizar perfil
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? fullName,
    String? profileImageUrl,
  }) async {
    try {
      final Map<String, dynamic> updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName;
      if (profileImageUrl != null) {
        updateData['profile_image_url'] = profileImageUrl;
      }

      await _supabase
          .from('users')
          .update(updateData)
          .eq('id', userId);

      return {'success': true};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Stream de autenticação
  Stream<AuthState> authStateChanges() {
    return _supabase.auth.onAuthStateChange;
  }
}