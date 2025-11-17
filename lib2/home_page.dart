import 'package:flutter/material.dart';

import 'login_page.dart';
import 'main.dart';
import 'user_list_page.dart';
import 'create_group_page.dart';

// 🚨 ATENÇÃO: O widget UserListPageState deve ser importado
// ou definido no user_list_page.dart sem o underscore, como corrigido acima.

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 🚀 CORREÇÃO 1: Usamos o nome de estado público (UserListPageState)
  final GlobalKey<UserListPageState> _userListKey =
      GlobalKey<UserListPageState>();

  // Função de Logout
  Future<void> _signOut() async {
    await supabase.auth.signOut();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<void> _navigateToCreateGroup() async {
    final shouldRefresh = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateGroupPage(),
      ),
    );

    if (shouldRefresh == true) {
      // 🚀 CORREÇÃO 2: Chamamos a função pública loadData()
      _userListKey.currentState?.loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supabase.auth.currentUser?.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contatos e Grupos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            tooltip: 'Criar Grupo',
            onPressed: _navigateToCreateGroup,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair (Logado como: $userEmail)',
            onPressed: _signOut,
          ),
        ],
      ),

      // Passa a chave para a UserListPage
      body: UserListPage(
        key: _userListKey,
      ),
    );
  }
}
