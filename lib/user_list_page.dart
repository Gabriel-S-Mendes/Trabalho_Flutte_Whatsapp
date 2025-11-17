import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'direct_message_page.dart';
import 'group_chat_page.dart';

// Modelo para combinar Perfis e Grupos
class ChatItem {
  final String id;
  final String title;
  final String? avatarUrl;
  final bool isGroup;
  final Map<String, dynamic> data;

  ChatItem({
    required this.id,
    required this.title,
    this.avatarUrl,
    required this.isGroup,
    required this.data,
  });
}

class UserListPage extends StatefulWidget {
  // callback opcional (você não precisa usá-lo agora)
  final VoidCallback? onRefresh;

  const UserListPage({super.key, this.onRefresh});

  @override
  State<UserListPage> createState() => UserListPageState();
}

// <-- Tornamos esta classe PÚBLICA (sem underscore) para poder ser usada em GlobalKey<>
class UserListPageState extends State<UserListPage> {
  Future<List<ChatItem>>? _combinedFuture;
  final User? currentUser = supabase.auth.currentUser;

  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    loadData();
    _searchController.addListener(_onSearchChanged);
  }

  // <-- Método público para ser chamado de fora via key.currentState?.loadData()
  void loadData() {
    if (currentUser != null) {
      setState(() {
        _combinedFuture = _fetchCombinedItems();
      });
    } else {
      setState(() {
        _combinedFuture = Future.value([]);
      });
    }
  }

  // MÉTODO PRINCIPAL: Busca perfis e grupos (Com filtro de duplicatas)
  Future<List<ChatItem>> _fetchCombinedItems() async {
    final currentUserId = currentUser!.id;

    // 1. FETCH DOS PERFIS (Usuários)
    final profilesData = await supabase
        .from('profiles')
        .select()
        .neq('id', currentUserId)
        .order('username', ascending: true);

    final profiles = (profilesData as List<dynamic>).map((user) {
      return ChatItem(
        id: user['id'] as String,
        title: user['username'] as String? ?? 'Usuário Sem Nome',
        avatarUrl: user['avatar_url'] as String?,
        isGroup: false,
        data: Map<String, dynamic>.from(user as Map),
      );
    }).toList();

    // 2. FETCH DOS GRUPOS (USANDO RPC)
    final groupsData = await supabase.rpc(
      'get_user_groups',
      params: {
        'user_id_input': currentUserId,
      },
    );

    // CORREÇÃO CONTRA DUPLICATAS
    final Set<String> processedGroupIds = {};
    final List<ChatItem> groups = [];

    for (final group in (groupsData as List<dynamic>)) {
      final groupId = group['id'] as String;

      if (!processedGroupIds.contains(groupId)) {
        groups.add(ChatItem(
          id: groupId,
          title: group['name'] as String? ?? 'Grupo Sem Nome',
          avatarUrl: null,
          isGroup: true,
          data: Map<String, dynamic>.from(group as Map),
        ));
        processedGroupIds.add(groupId);
      }
    }

    // 3. COMBINAÇÃO E ORDENAÇÃO FINAL
    final allItems = [...profiles, ...groups];
    allItems
        .sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return allItems;
  }

  void _onSearchChanged() {
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
    // AppBar removido propositalmente (você tem AppBar na HomePage)
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextFormField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nome de usuário ou grupo...',
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
          child: FutureBuilder<List<ChatItem>>(
            future: _combinedFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                    child: Text('Erro ao carregar contatos: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent)));
              }

              final rawItems = snapshot.data ?? [];

              final filteredItems = rawItems.where((item) {
                final name = item.title.toLowerCase();
                return name.contains(_searchTerm);
              }).toList();

              final items = filteredItems;

              if (items.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30.0),
                    child: Text(
                      _searchTerm.isNotEmpty
                          ? 'Nenhum usuário ou grupo encontrado com o nome "$_searchTerm".'
                          : 'Nenhum contato ou grupo cadastrado.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  final IconData leadingIcon =
                      item.isGroup ? Icons.people : Icons.person;
                  final Color avatarColor = item.isGroup
                      ? Colors.green.shade700
                      : Colors.blueGrey.shade700;

                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                    child: ListTile(
                      tileColor: Colors.transparent,
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: avatarColor,
                        backgroundImage:
                            item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                                ? NetworkImage(item.avatarUrl!)
                                : null,
                        child: (item.avatarUrl == null ||
                                item.avatarUrl!.isEmpty)
                            ? Icon(leadingIcon, size: 30, color: Colors.white70)
                            : null,
                      ),
                      title: Text(item.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text(
                        item.isGroup
                            ? 'Grupo'
                            : 'Toque para iniciar a conversa',
                        style: TextStyle(
                            color: item.isGroup
                                ? Colors.greenAccent
                                : Colors.grey),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios,
                          size: 16, color: Colors.grey),
                      onTap: () {
                        final Widget targetPage = item.isGroup
                            ? GroupChatPage(
                                groupId: item.id, groupName: item.title)
                            : DirectMessagePage(recipientProfile: item.data);

                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => targetPage),
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
    );
  }
}
