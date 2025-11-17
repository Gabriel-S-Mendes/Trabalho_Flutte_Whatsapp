import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'main.dart'; // supabase client

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  /// IMAGEM:
  File? _avatarFile;         // mobile
  Uint8List? _avatarBytes;   // web
  String? _avatarName;       // web

  // =============================
  // Selecionar imagem (mobile + web)
  // =============================

  Future<void> _pickImage() async {
    if (kIsWeb) {
      // ------ WEB ------
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;

      setState(() {
        _avatarBytes = result.files.first.bytes;
        _avatarName = result.files.first.name;
      });
    } else {
      // ------ MOBILE ------
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
      );
      if (image == null) return;

      setState(() {
        _avatarFile = File(image.path);
      });
    }
  }

  // =============================
  // Upload da imagem
  // =============================
  Future<String> _uploadAvatar(String userId) async {
    const bucket = 'avatars';

    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}'
        '_${_avatarName ?? "avatar.jpg"}';

    if (kIsWeb) {
      // WEB USE uploadBinary
      await supabase.storage.from(bucket).uploadBinary(
            fileName,
            _avatarBytes!,
            fileOptions: const FileOptions(upsert: true),
          );
    } else {
      // MOBILE usa File
      await supabase.storage.from(bucket).upload(
            fileName,
            _avatarFile!,
            fileOptions: const FileOptions(upsert: true),
          );
    }

    // Retorna URL pública
    return supabase.storage.from(bucket).getPublicUrl(fileName);
  }

  // =============================
  // Cadastro
  // =============================
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    if (!kIsWeb && _avatarFile == null ||
        kIsWeb && _avatarBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma foto de perfil.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Criar usuário
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = res.user;
      final session = res.session;

      if (user == null || session == null) {
        // Email confirmation necessária
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              "Verifique seu email para confirmar o cadastro."),
          backgroundColor: Colors.orange,
        ));
        if (mounted) Navigator.pop(context);
        return;
      }

      // 2. Upload do avatar
      final avatarUrl = await _uploadAvatar(user.id);

      // 3. Atualizar perfil no DB
      await supabase.from('profiles').upsert({
        'id': user.id,
        'username': _usernameController.text.trim(),
        'avatar_url': avatarUrl,
      });

      // 4. Navegar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Cadastro realizado com sucesso!'),
          backgroundColor: Colors.green,
        ));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    }

    on StorageException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro no Storage: ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
    }

    on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro de autenticação: ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
    }

    catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro inesperado: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =============================
  // UI
  // =============================
  @override
  Widget build(BuildContext context) {
    final imageWidget = kIsWeb
        ? (_avatarBytes != null
            ? CircleAvatar(radius: 60, backgroundImage: MemoryImage(_avatarBytes!))
            : const CircleAvatar(radius: 60, child: Icon(Icons.camera_alt, size: 40)))
        : (_avatarFile != null
            ? CircleAvatar(radius: 60, backgroundImage: FileImage(_avatarFile!))
            : const CircleAvatar(radius: 60, child: Icon(Icons.camera_alt, size: 40)));

    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text('Cadastro Completo',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),

                GestureDetector(
                  onTap: _pickImage,
                  child: imageWidget,
                ),
                const SizedBox(height: 8),
                const Text('Clique para adicionar foto'),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Nome de Usuário'),
                  validator: (v) => v == null || v.length < 3
                      ? 'Mínimo de 3 caracteres'
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) => v == null || !v.contains("@")
                      ? 'Email inválido'
                      : null,
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Senha'),
                  obscureText: true,
                  validator: (v) => v == null || v.length < 6
                      ? 'Mínimo 6 caracteres'
                      : null,
                ),

                const SizedBox(height: 24),

                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _signUp,
                        child: const Text('Cadastrar e Entrar'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
