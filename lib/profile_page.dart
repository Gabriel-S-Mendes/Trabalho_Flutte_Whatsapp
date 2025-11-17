import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'main.dart';
// Não precisamos do import 'login_page.dart' aqui, pois a função onSignOut
// (que vem da HomePage) já cuida da navegação.

// ----------------------------------------------------------
// 👤 TELA PRINCIPAL DE PERFIL
// ----------------------------------------------------------
class ProfilePage extends StatefulWidget {
  // 🚨 NOVO: Recebe o callback da função de deslogar da HomePage
  final Future<void> Function() onSignOut;

  const ProfilePage({super.key, required this.onSignOut});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  final _picker = ImagePicker();

  // Dados do perfil atualmente logado
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  final User? currentUser = supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // 📥 FUNÇÃO: CARREGAR PERFIL
  // ----------------------------------------------------------
  Future<void> _loadProfile() async {
    if (currentUser == null) {
      _showSnackBar(context, 'Usuário não autenticado.');
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('*')
          .eq('id', currentUser!.id)
          .single();

      setState(() {
        _profileData = profile;
        _usernameController.text = profile['username'] ?? '';
      });
    } on PostgrestException catch (error) {
      _showSnackBar(context, 'Erro ao carregar perfil: ${error.message}');
    } catch (error) {
      _showSnackBar(context, 'Erro inesperado: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ----------------------------------------------------------
  // 📤 FUNÇÃO: ATUALIZAR NOME DE USUÁRIO
  // ----------------------------------------------------------
  Future<void> _updateUsername() async {
    if (currentUser == null || _isLoading) return;

    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      await supabase.from('profiles').update({
        'username': newUsername,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', currentUser!.id);

      _showSnackBar(context, 'Nome de usuário atualizado com sucesso!');
      await _loadProfile();
    } on PostgrestException catch (error) {
      _showSnackBar(context, 'Erro ao atualizar: ${error.message}');
    } catch (error) {
      _showSnackBar(context, 'Erro inesperado: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ----------------------------------------------------------
  // 🖼️ FUNÇÃO: ENVIAR AVATAR
  // ----------------------------------------------------------
  Future<void> _uploadAvatar() async {
    if (currentUser == null || _isLoading) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 300,
      maxHeight: 300,
    );

    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    try {
      final file = File(pickedFile.path);
      final fileExtension = pickedFile.path.split('.').last;
      final fileName =
          '${currentUser!.id}/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      // 1. UPLOAD para o Storage
      await supabase.storage.from('avatars').upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );

      // 2. OBTENÇÃO da URL pública
      final imageUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

      // 3. ATUALIZAÇÃO do campo 'avatar_url' na tabela 'profiles'
      await supabase.from('profiles').update({
        'avatar_url': imageUrl,
      }).eq('id', currentUser!.id);

      _showSnackBar(context, 'Imagem de perfil atualizada!');
      await _loadProfile();
    } on StorageException catch (error) {
      _showSnackBar(context, 'Erro de Storage: ${error.message}');
    } catch (error) {
      _showSnackBar(context, 'Erro inesperado ao enviar avatar: $error');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ----------------------------------------------------------
  // 🚪 FUNÇÃO: DESLOGAR (CHAMA O CALLBACK DA HOMEPAGE)
  // ----------------------------------------------------------
  Future<void> _signOut() async {
    // 🚨 CORREÇÃO: Chama a função que veio da HomePage, que contém a
    // lógica de setar o status Offline e navegar para a LoginPage.
    await widget.onSignOut();
  }

  // ----------------------------------------------------------
  // 💡 HELPER: SNACKBAR
  // ----------------------------------------------------------
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ----------------------------------------------------------
  // 🖥️ INTERFACE
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meu Perfil')),
        body: const Center(child: Text('Usuário não logado.')),
      );
    }

    if (_isLoading || _profileData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meu Perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final avatarUrl = _profileData!['avatar_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meu Perfil'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagem de Perfil (Avatar)
            GestureDetector(
              onTap: _uploadAvatar,
              child: Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade700,
                      backgroundImage:
                          (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(avatarUrl)
                              : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.white70)
                          : null,
                    ),
                    const Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blueAccent,
                        child: Icon(Icons.camera_alt,
                            size: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // E-mail (Somente Leitura)
            Text(
              'E-mail: ${currentUser!.email}',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
            ),

            const SizedBox(height: 16),

            // Nome de Usuário (Editável)
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Nome de Usuário',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            // Botão Salvar
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateUsername,
              icon: const Icon(Icons.save),
              label:
                  Text(_isLoading ? 'Salvando...' : 'Salvar Nome de Usuário'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),

            const Spacer(),

            // Botão Deslogar
            TextButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                'Deslogar',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
