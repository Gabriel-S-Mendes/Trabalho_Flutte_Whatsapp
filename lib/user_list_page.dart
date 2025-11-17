import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'direct_message_page.dart';

class UserListPage extends StatefulWidget {
  const UserListPage({super.key});

  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  // O Stream agora carrega ABSOLUTAMENTE TUDO do servidor.
  late final Stream<List<Map<String, dynamic>>> _profilesStream;
  final User? currentUser = supabase.auth.currentUser;

  // Controller e Termo de Busca
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();

    if (currentUser != null) {
      // QUERY MAIS SIMPLES: Apenas busca todos os perfis ordenados.
      _profilesStream = supabase
          .from('profiles')
          .stream(primaryKey: ['id']).order('username', ascending: true);
    } else {
      _profilesStream = const Stream.empty();
    }

    // Adiciona listener para capturar o que o usuário digita
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Atualiza o estado com o termo de busca em minúsculas
    setState(() {
      _searchTerm = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🎯 CORRIGIDO: Removendo o AppBar para eliminar o título duplicado "Contatos".
      body: Column(
        children: [
          // Campo de Pesquisa (UI)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextFormField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome de usuário...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey.shade800,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              ),
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _profilesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text(
                          'Erro ao carregar usuários: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent)));
                }

                final rawUsers = snapshot.data ?? [];

                // FILTRAGEM NO CLIENTE: APLICANDO NEQ (usuário logado) e LIKE (pesquisa)
                final filteredUsers = rawUsers.where((user) {
                  // 1. Filtro NEQ: Exclui o próprio usuário
                  if (user['id'] == currentUser!.id) {
                    return false;
                  }

                  // 2. Filtro LIKE: Pesquisa por termo digitado
                  final username =
                      (user['username'] as String? ?? '').toLowerCase();
                  return username.contains(_searchTerm);
                }).toList();

                final users =
                    filteredUsers; // Usamos a lista duplamente filtrada

                if (users.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(30.0),
                      child: Text(
                        _searchTerm.isNotEmpty
                            ? 'Nenhum usuário encontrado com o nome "$_searchTerm".'
                            : 'Nenhum outro usuário cadastrado foi encontrado. Crie outro usuário para iniciar um DM!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
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
                    final String avatarUrl =
                        user['avatar_url'] as String? ?? '';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 0, vertical: 2),
                      child: ListTile(
                        tileColor: Colors.transparent, // Fundo transparente
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.blueGrey.shade700,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
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
                          // Navega para a tela de mensagem direta
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
          ),
        ],
      ),
    );
  }
}
