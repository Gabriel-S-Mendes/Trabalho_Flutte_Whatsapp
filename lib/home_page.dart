import 'package:flutter/material.dart';
import 'login_page.dart';
import 'main.dart'; // Para acessar o 'supabase' client

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Pega o email do usuário logado (opcional)
    final userEmail = supabase.auth.currentUser?.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Faz o logout
              await supabase.auth.signOut();

              // Redireciona para a tela de Login
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              }
            },
          )
        ],
      ),
      body: Center(
        child: Text('Bem-vindo, $userEmail!'),
      ),
    );
  }
}