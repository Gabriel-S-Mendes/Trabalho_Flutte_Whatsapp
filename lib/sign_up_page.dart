import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart'; // Tela de destino após o cadastro
import 'main.dart';      // Para acessar o cliente 'supabase'

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _signUp() async {
    // 1. Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Chama a função de cadastro do Supabase
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 3. Verifica o resultado
      if (res.user != null) {
        // Usuário criado com sucesso. O Supabase enviará um email de confirmação.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sucesso! Verifique seu email para confirmar a conta.'),
              backgroundColor: Colors.green,
            ),
          );
          // Opcional: Navegar para a tela Home (se você desativou a confirmação por email no Supabase)
          // OU navegar para a tela de Login para que o usuário faça o primeiro login.
          // Neste exemplo, vamos apenas notificar e voltar.
          Navigator.of(context).pop(); 
        }
      } else if (res.session == null) {
         // O cadastro é bem-sucedido, mas a sessão não é iniciada porque a confirmação por email está ativada (padrão do Supabase).
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Verifique seu email para completar o cadastro.'),
                backgroundColor: Colors.orange,
              ),
            );
             Navigator.of(context).pop(); 
         }
      }
      
    } on AuthException catch (error) {
      // 4. Trata erros de autenticação (ex: senha muito fraca, email já existe)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      // 5. Trata outros erros
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro')),
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
                  'Crie sua conta',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
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
                        child: const Text('Cadastrar'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}