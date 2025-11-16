import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'main.dart';
import 'user_list_page.dart'; // 💡 NOVO: Importa a tela para listar os usuários (contatos)

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Função de Logout (mantida)
  Future<void> _signOut() async {
    await supabase.auth.signOut();

    if (mounted) {
      // Retorna para a tela de login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Acessa o email do usuário logado
    final userEmail = supabase.auth.currentUser?.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat DM'),
        actions: [
          // 💡 Botão que leva para a lista de todos os usuários (Contatos)
          IconButton(
            icon: const Icon(Icons.people_alt),
            tooltip: 'Lista de Contatos',
            onPressed: () {
              // Navega para a lista de usuários (Passo 2)
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const UserListPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: _signOut,
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Bem-vindo ao seu aplicativo de DM!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Toque no ícone de pessoas na barra superior para iniciar uma conversa privada com qualquer usuário cadastrado.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            // Exibe o email do usuário logado
            Text(
              'Logado como: $userEmail',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
