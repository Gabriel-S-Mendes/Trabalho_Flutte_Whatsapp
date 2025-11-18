import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_page.dart';
import 'main.dart'; // cliente supabase

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

  // ===========================================
  // CORES DO TEMA UNIFICADO
  // ===========================================
  // Cor de Destaque (AppBar e Botões)
  static const Color primaryHighlightColor = Color(0xFF00A38E);
  // Fundo principal (Scaffold)
  static const Color darkBackgroundColor = Color(0xFF1E1E1E);
  // Fundo do Card (levemente mais claro que o fundo)
  static const Color cardBackgroundColor = Color(0xFF2C2C2C);
  // Cor do texto claro
  static const Color lightTextColor = Colors.white;

  // =============================
  // Cadastro (Sign Up) - LÓGICA ORIGINAL
  // =============================
  Future<void> _signUp() async {
    // 1. Validar os campos do formulário
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 2. Criar usuário (Supabase Auth)
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final user = res.user;
      final session = res.session;

      // Se a sessão for nula, a confirmação por e-mail é necessária
      if (user != null && session == null) {
        // Confirmação de e-mail necessária
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Verifique seu e-mail para confirmar o cadastro."),
          backgroundColor: Colors.orange,
        ));
        if (mounted) Navigator.pop(context); // Volta para a tela anterior
        return;
      }

      // Se a sessão estiver presente, o usuário fez login imediatamente
      if (user != null && session != null) {
        // 3. Criar perfil no DB (tabela 'profiles') - USANDO 'username' COMO NO ORIGINAL
        await supabase.from('profiles').upsert({
          'id': user.id,
          'username': _usernameController.text.trim(),
          // 'avatar_url' foi removido
        });

        // 4. Navegar para a HomePage
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
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro de autenticação: ${e.message}"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erro inesperado: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =============================
  // UI - DESIGN DARK MODE
  // =============================

  // Estilo de borda para os campos de texto
  OutlineInputBorder _inputBorder(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color, width: 1.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fundo principal escuro
      backgroundColor: darkBackgroundColor,

      appBar: AppBar(
        title: const Text('Criar Conta'),
        // AppBar Verde-Água
        backgroundColor: primaryHighlightColor,
        foregroundColor: lightTextColor,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          // Card em um cinza mais claro para destaque
          child: Card(
            color: cardBackgroundColor,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(
                  color: primaryHighlightColor,
                  width: 1), // Borda sutil de destaque
            ),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Crie Sua Conta',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: primaryHighlightColor, // Título Verde-Água
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Campo Nome de Usuário
                    TextFormField(
                      controller: _usernameController,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(
                          color: lightTextColor), // Texto digitado branco
                      decoration: InputDecoration(
                        labelText: 'Nome de Usuário',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.person,
                            color: primaryHighlightColor),
                        border: _inputBorder(Colors.grey.shade600),
                        enabledBorder: _inputBorder(Colors.grey.shade700),
                        focusedBorder: _inputBorder(primaryHighlightColor),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 16.0),
                      ),
                      validator: (v) => v == null || v.length < 3
                          ? 'Mínimo de 3 caracteres'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Campo E-mail
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(
                          color: lightTextColor), // Texto digitado branco
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.email,
                            color: primaryHighlightColor),
                        border: _inputBorder(Colors.grey.shade600),
                        enabledBorder: _inputBorder(Colors.grey.shade700),
                        focusedBorder: _inputBorder(primaryHighlightColor),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 16.0),
                      ),
                      validator: (v) => v == null || !v.contains("@")
                          ? 'E-mail inválido'
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Campo Senha
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(
                          color: lightTextColor), // Texto digitado branco
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        labelStyle: const TextStyle(color: Colors.grey),
                        prefixIcon: const Icon(Icons.lock,
                            color: primaryHighlightColor),
                        border: _inputBorder(Colors.grey.shade600),
                        enabledBorder: _inputBorder(Colors.grey.shade700),
                        focusedBorder: _inputBorder(primaryHighlightColor),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 16.0, horizontal: 16.0),
                      ),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 6
                          ? 'Mínimo 6 caracteres'
                          : null,
                    ),

                    const SizedBox(height: 32),

                    _isLoading
                        ? const CircularProgressIndicator(
                            color: primaryHighlightColor)
                        : SizedBox(
                            width: double.infinity, // Botão de largura total
                            child: ElevatedButton(
                              onPressed: _signUp,
                              style: ElevatedButton.styleFrom(
                                // Botão Verde-Água
                                backgroundColor: primaryHighlightColor,
                                foregroundColor: lightTextColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 5,
                              ),
                              child: const Text(
                                'Cadastrar e Entrar',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
