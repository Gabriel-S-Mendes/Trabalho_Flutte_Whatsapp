import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'main.dart';
import 'user_list_page.dart'; // Importa a tela para listar os usuários (contatos)

// Convertido para StatelessWidget, pois o estado (StatefulWidget) não é mais necessário
// nesta tela, que agora só hospeda a UserListPage.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // Função de Logout
  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();

    // Verifica se o Widget ainda está montado antes de navegar
    if (context.mounted) {
      // Retorna para a tela de login
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
        // Título alterado para refletir o novo conteúdo da tela
        title: const Text('Contatos do Chat'),
        actions: [
          // O botão de contatos foi removido, pois a lista agora é o corpo da tela.
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sair (Logado como: $userEmail)',
            // Chama a função _signOut passando o contexto
            onPressed: () => _signOut(context),
          )
        ],
      ),

      // MODIFICAÇÃO PRINCIPAL: Substitui o conteúdo estático pela UserListPage
      body: const UserListPage(),
    );
  }
}
