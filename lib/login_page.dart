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
    // 1. Redirecionamento de Sessão
    _checkInitialSession();
  }

  // Verifica se já existe uma sessão ativa
  void _checkInitialSession() {
    final session = supabase.auth.currentSession;
    if (session != null) {
      // Se houver sessão, navega imediatamente para a Home
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      });
    }
  }

  Future<void> _signIn() async {
    // 2. Validação mais clara
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // O Supabase SDK fará o trim do email/senha, mas manter o trim aqui é uma boa prática
      await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Se logado com sucesso, o Session Listener (que geralmente está no Widget pai ou no main)
      // é a forma mais robusta de lidar com a navegação.
      // Contudo, para fins práticos e seguindo o seu código, mantemos a navegação direta aqui.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        _showSnackBar(context, error.message, isError: true);
      }
    } catch (error) {
      if (mounted) {
        _showSnackBar(context, 'Ocorreu um erro inesperado: $error',
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

  // Função auxiliar para exibir o SnackBar
  void _showSnackBar(BuildContext context, String message,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating, // Melhor UX
      ),
    );
  }

  // Função para lidar com o "Esqueceu a senha"
  Future<void> _forgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showSnackBar(context, 'Por favor, digite seu email primeiro.',
          isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Aqui você inicia o fluxo de recuperação de senha do Supabase
      await supabase.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        // Redireciona o usuário para um link onde ele completará a mudança de senha.
        // Certifique-se de configurar o URL de redirecionamento no Supabase
        // redirectTo: 'sua-url-de-deep-link-ou-web',
      );

      if (mounted) {
        _showSnackBar(
            context, 'Link de redefinição enviado para o seu email!');
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
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Adicione um Logo ou Título de destaque
                const Text(
                  'Bem-vindo de volta!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(), // Estilo melhorado
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value.trim())) {
                      return 'Por favor, insira um email válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(), // Estilo melhorado
                    // Adiciona o ícone para alternar a visibilidade da senha
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
                  obscureText: !_isPasswordVisible, // Controla a visibilidade
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'A senha deve ter pelo menos 6 caracteres'; // Melhor feedback
                    }
                    return null;
                  },
                  // Permite submeter o formulário ao pressionar 'Enter'
                  onFieldSubmitted: (_) => _signIn(),
                ),
                const SizedBox(height: 8),

                // Link para "Esqueceu a Senha"
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Esqueceu a senha?'),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Botão de Login (com Loading)
                SizedBox(
                  height: 50, // Altura padrão de botão
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _signIn,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      // Você pode definir cores personalizadas aqui
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
                const SizedBox(height: 24),

                // Link para o Cadastro
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => SignUpPage()),
                          );
                        },
                  child: const Text('Não tem uma conta? Cadastre-se'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}