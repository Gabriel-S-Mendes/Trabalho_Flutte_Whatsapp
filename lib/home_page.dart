import 'package:flutter/material.dart';

import 'login_page.dart';
import 'main.dart';
import 'user_list_page.dart'; // Contém a definição de UserListPage e UserListPageState
import 'create_group_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ===========================================
  // CORES PARA O TEMA:
  // 1. Cor de Destaque (AppBar) - Green/Teal
  // 2. Fundo do Corpo (Dark Mode)
  // 3. Cor do Texto
  // ===========================================
  // Cor de Destaque da sua tela de Login (Verde-Água)
  static const Color primaryHighlightColor = Color(0xFF00A38E);
  static const Color darkBackgroundColor =
      Color(0xFF1E1E1E); // Fundo Cinza Escuro para o corpo
  static const Color lightTextColor = Colors.white; // Texto principal claro

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
      backgroundColor:
          darkBackgroundColor, // Fundo do Scaffold (Corpo da lista)

      appBar: AppBar(
        title: const Text('Contatos e Grupos',
            style: TextStyle(color: lightTextColor)), // Título Branco
        centerTitle: true,
        backgroundColor:
            primaryHighlightColor, // 👈 COR DE DESTAQUE (Verde-Água)
        foregroundColor: lightTextColor, // Ícones Brancos
        elevation: 4, // Adiciona uma leve sombra para separação
        actions: [
          // 🎯 BOTÃO DE PERFIL
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

          // ⚠️ Ícone de Logout (em uma cor que se destaca, mas suave)
          IconButton(
            icon: const Icon(Icons.logout,
                color:
                    lightTextColor), // Mantive branco para contraste, ou você pode usar um vermelho suave: Color.fromARGB(255, 255, 179, 179)
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
