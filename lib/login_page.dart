import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart'; // Certifique-se de que esta página existe
import 'sign_up_page.dart'; // Certifique-se de que esta página existe
import 'main.dart'; // Para acessar o 'supabase' client

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  // Variável para controlar a visibilidade da senha
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    // 1. Redirecionamento de Sessão: Verifica se já existe uma sessão ativa.
    _checkInitialSession();
  }

  // Verifica se já existe uma sessão ativa e navega para a Home, se sim.
  void _checkInitialSession() {
    final session = supabase.auth.currentSession;
    if (session != null) {
      // Usa addPostFrameCallback para garantir que a navegação ocorra após a construção do widget.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      });
    }
  }

  Future<void> _signIn() async {
    // 2. Validação: Checa se o formulário está válido antes de prosseguir.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Tenta fazer o login com email e senha.
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Se logado com sucesso, navega para a HomePage.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on AuthException catch (error) {
      // Trata erros específicos de autenticação do Supabase.
      if (mounted) {
        _showSnackBar(context, error.message, isError: true);
      }
    } catch (error) {
      // Trata outros erros inesperados.
      if (mounted) {
        _showSnackBar(context, 'Ocorreu um erro inesperado: $error',
            isError: true);
      }
    } finally {
      // Garante que o indicador de carregamento seja removido.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Função auxiliar para exibir o SnackBar (notificação)
  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red.shade700
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Função para lidar com o "Esqueceu a senha"
  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar(context, 'Por favor, digite seu email para redefinição.',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        // Opcional: Especifique um redirectTo para Deep Linking no seu app.
        // redirectTo: 'sua-url-de-deep-link-ou-web',
      );

      if (mounted) {
        _showSnackBar(context, 'Link de redefinição enviado para o seu email!');
      }
    } on AuthException catch (error) {
      if (mounted) {
        _showSnackBar(context, error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(context, 'Erro ao enviar link de redefinição.',
            isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrar'),
        elevation: 0, // Remove a sombra para um visual mais limpo
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(
              32.0), // Aumentei o padding para melhor visualização
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Título de destaque
                Text(
                  'Bem-vindo de volta!',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800, // Deixei mais destacado
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Faça login na sua conta para continuar',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Campo de Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'O campo de email é obrigatório';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                        .hasMatch(value.trim())) {
                      return 'Por favor, insira um email válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo de Senha
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10))),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _isLoading
                      ? null
                      : _signIn(), // Submete ao pressionar 'Enter'
                ),
                const SizedBox(height: 8),

                // Link para "Esqueceu a Senha"
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _forgotPassword,
                    child: const Text('Esqueceu a senha?',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),

                // Botão de Login (com Loading Indicator)
                SizedBox(
                  height: 56, // Altura maior para melhor toque
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      // Usa a cor primária do tema para o botão
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 4, // Adiciona uma leve sombra
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                // Link para o Cadastro
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const SignUpPage()),
                          );
                        },
                  child: const Text(
                    'Não tem uma conta? Cadastre-se',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
