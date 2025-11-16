import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart'; 
import 'main.dart';      // Para acessar o cliente 'supabase'

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController(); // Novo: Campo para Nome de Usuário
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  File? _avatarFile; // Novo: Para armazenar a foto selecionada

  // Lógica de Upload para o Supabase Storage (copiada de ProfileSetupPage)
  Future<String> _uploadAvatar(File file) async {
    final bytes = await file.readAsBytes();
    final fileExt = file.path.split('.').last;
    final userId = supabase.auth.currentUser!.id;
    final fileName = '${userId}_${DateTime.now().microsecondsSinceEpoch}.$fileExt';
    
    // Caminho no Supabase Storage: Buckets > avatars
    await supabase.storage.from('avatars').uploadBinary(
      fileName, 
      bytes,
      fileOptions: const FileOptions(
        upsert: true,
        contentType: 'image/jpeg',
      ),
    );

    // Retorna a URL pública para salvar no banco de dados 'profiles'
    return supabase.storage.from('avatars').getPublicUrl(fileName);
  }

  Future<void> _signUp() async {
    // 1. Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // 1.1. Verifica se a foto foi selecionada
    if (_avatarFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecione uma foto de perfil.')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Chama a função de cadastro do Supabase (cria o auth.users e o registro em public.profiles)
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        // Você pode passar o username como "data", mas o trigger no DB já cuida do profiles
        data: {'username': _usernameController.text.trim()}, 
      );
      
      // Checagem de sessão após cadastro
      final session = res.session;
      final user = res.user;

      if (session == null || user == null) {
        // Se a sessão for nula, a confirmação por email está ativada.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verifique seu email para completar o cadastro. Você precisará fazer login depois.'),
              backgroundColor: Colors.orange,
            ),
          );
          Navigator.of(context).pop(); // Volta para a tela de Login
        }
      } else {
        // 3. Usuário logado automaticamente: Faz o upload da foto e atualiza o perfil
        String avatarUrl = await _uploadAvatar(_avatarFile!);

        // 4. ATUALIZA A TABELA DE PROFILES com a foto e o nome de usuário (confirmando a informação)
        await supabase.from('profiles').update({
          'username': _usernameController.text.trim(),
          'avatar_url': avatarUrl,
        }).eq('id', user.id);

        // 5. NAVEGAÇÃO para a Home Page
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cadastro e Perfil criados com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      }
      
    } on AuthException catch (error) {
      // 6. Trata erros de autenticação (ex: senha muito fraca, email já existe)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro no Storage: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      // 7. Trata outros erros
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocorreu um erro inesperado durante o cadastro.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); // Reduz a qualidade
    
    if (image != null) {
      setState(() {
        _avatarFile = File(image.path);
      });
    }
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar Conta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Cadastro Completo',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Widget de Foto de Perfil
               GestureDetector(
                onTap: _pickImage,
                 child: CircleAvatar(
                     radius: 60,
                         backgroundColor: Colors.grey[800],
                            backgroundImage: _avatarFile != null 
                               ? FileImage(_avatarFile!) // <- Se o _avatarFile for nulo, a imagem não aparece.
                                 : null,
                                        child: _avatarFile == null
                                            ? const Icon(Icons.camera_alt, size: 40, color: Colors.white)
                                              : null,
                                                 ),
                                                    ),
                const SizedBox(height: 10),
                const Text('Clique para adicionar foto', textAlign: TextAlign.center),
                const SizedBox(height: 30),

                // Campo Nome de Usuário
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Nome de Usuário'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'O nome é obrigatório';
                    }
                    if (value.length < 3) {
                       return 'Mínimo de 3 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty || !value.contains('@')) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),  
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Senha (mínimo 6 caracteres)'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
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