import 'package:flutter/material.dart';

import 'login_page.dart';
import 'main.dart';
import 'user_list_page.dart'; // Contém a definição de UserListPage e UserListPageState
import 'create_group_page.dart';
import 'profile_page.dart'; // 👈 NOVA IMPORTAÇÃO para a tela de perfil

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // 🚀 Usamos o nome de estado público (UserListPageState)
  final GlobalKey<UserListPageState> _userListKey =
      GlobalKey<UserListPageState>();

  // Função de Logout (Contém a lógica de setar Offline)
  Future<void> _signOut() async {
    // 1. CHAMA O MÉTODO PARA MUDAR O STATUS PARA OFFLINE (FALSE)
    await _userListKey.currentState?.updateOnlineStatus(false);

    // 2. DESLOGA O USUÁRIO DA SESSÃO SUPABASE
    await supabase.auth.signOut();

    if (mounted) {
      // 3. NAVEGA PARA A TELA DE LOGIN
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
      // 🚀 Chamamos a função pública loadData()
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
          // 🎯 BOTÃO DE PERFIL (CORRIGIDO)
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Meu Perfil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    // Passando o callback obrigatório
                    onSignOut: _signOut,
                  ),
                ),
              );
            },
          ),

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
