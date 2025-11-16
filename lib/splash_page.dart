import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'main.dart'; // Para acessar o 'supabase' client

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  _SplashPageState createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _redirect(); // Inicia a verificação assim que a tela é construída
  }

  Future<void> _redirect() async {
    // Aguarda um pequeno instante para garantir que o widget está pronto
    await Future.delayed(Duration.zero);

    // Verifica a sessão atual
    final session = supabase.auth.currentSession;

    if (!mounted) return; // Garante que o widget ainda está na árvore

    if (session != null) {
      // Usuário está logado
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    } else {
      // Usuário não está logado
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tela de carregamento simples
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}