import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'login_page.dart';
import 'main.dart';
import 'user_list_page.dart';
import 'create_group_page.dart'; // <-- Import da nova tela de criação de grupos

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Função de Logout
  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supabase.auth.currentUser?.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contatos do Chat'),
        actions: [
          // 👉 Botão para criar grupo (NOVO)
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Criar Grupo',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CreateGroupPage(),
                ),
              );
            },
          ),

          // Botão de logout
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair (Logado como: $userEmail)',
            onPressed: () => _signOut(context),
          ),
        ],
      ),

      // A página de contatos permanece como corpo
      body: const UserListPage(),
    );
  }
}
