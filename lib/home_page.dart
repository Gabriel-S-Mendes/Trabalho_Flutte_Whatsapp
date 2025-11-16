import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';
import 'main.dart'; // Para acessar o 'supabase' client
import 'chat_screen.dart'; // 💡 NOVO: Importa a tela de mensagens

// Mude de StatelessWidget para StatefulWidget
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Função para buscar a lista de salas na sua nova tabela 'rooms'
  Future<List<Map<String, dynamic>>> _fetchRooms() async {
    // Busca as colunas 'id' e 'name' da tabela 'rooms'
    final data = await supabase
        .from('rooms')
        .select('id, name')
        .order('created_at', ascending: false);
    return data;
  }

  // Função de Logout (mantida)
  Future<void> _signOut() async {
    await supabase.auth.signOut();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pega o email do usuário logado (apenas para referência)
    final userEmail = supabase.auth.currentUser?.email ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conversas'), // Novo título
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut, // Chama a nova função de logout
          )
        ],
      ),
      // O corpo agora usa o FutureBuilder para exibir a lista de salas.
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // 1. Qual dado buscar? A lista de salas
        future: _fetchRooms(),
        builder: (context, snapshot) {
          // 2. Se está carregando, mostra o spinner
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 3. Se deu erro, mostra a mensagem de erro
          if (snapshot.hasError) {
            return Center(
                child: Text('Erro ao carregar conversas: ${snapshot.error}'));
          }

          // 4. Pega a lista de salas (conversas)
          final rooms = snapshot.data ?? [];

          // 5. Se a lista estiver vazia
          if (rooms.isEmpty) {
            return const Center(
                child:
                    Text('Nenhuma conversa encontrada. Crie uma nova sala!'));
          }

          // 6. Constrói a lista visual (como no WhatsApp)
          return ListView.builder(
            itemCount: rooms.length,
            itemBuilder: (context, index) {
              final room = rooms[index];
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.chat_bubble_outline, color: Colors.white),
                ),
                title: Text(room['name'] ?? 'Chat de Grupo'),
                subtitle: Text('ID da Sala: ${room['id']}'),
                // 💡 NOVO: AÇÃO AO CLICAR NA CONVERSA
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        // Passa o ID e o Nome da sala para a próxima tela
                        roomId: room['id'] as String,
                        roomName: room['name'] as String,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
