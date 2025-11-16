import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
// 💡 Mudamos o import para usar a nova tela de chat refatorada (V2)
import 'direct_message_page.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  late final Stream<List<Map<String, dynamic>>> _profilesStream;
  final User? currentUser = supabase.auth.currentUser;

  @override
  void initState() {
    super.initState();
    if (currentUser != null) {
      // Seleciona todos os perfis, exceto o do usuário atual.
      _profilesStream = supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .neq('id', currentUser!.id) // Filtra o próprio usuário
          .order('username', ascending: true);
    } else {
      // Se o usuário não estiver logado
      _profilesStream = const Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seus Contatos DM'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _profilesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
                child: Text('Erro ao carregar usuários: ${snapshot.error}',
                    style: const TextStyle(color: Colors.redAccent)));
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30.0),
                child: Text(
                  'Nenhum outro usuário cadastrado foi encontrado. Crie outro usuário para iniciar um DM!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final String username =
                  user['username'] as String? ?? 'Usuário Sem Nome';
              final String avatarUrl = user['avatar_url'] as String? ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                child: ListTile(
                  tileColor: Colors.transparent, // Fundo transparente
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.blueGrey.shade700,
                    backgroundImage:
                        avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person,
                            size: 30, color: Colors.white70)
                        : null,
                  ),
                  title: Text(username,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  subtitle: const Text(
                    'Toque para iniciar a conversa',
                    style: TextStyle(color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey),
                  onTap: () {
                    // 🚨 AQUI ESTÁ A MUDANÇA MAIS IMPORTANTE:
                    // Usamos a nova DirectMessagePageV2
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DirectMessagePage(
                          // Passa o perfil do destinatário para a próxima tela
                          recipientProfile: user,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
