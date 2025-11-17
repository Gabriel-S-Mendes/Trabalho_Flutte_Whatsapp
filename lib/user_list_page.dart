import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Certifique-se de que a variável global 'supabase' está aqui
import 'direct_message_page.dart'; // Importação obrigatória
import 'group_chat_page.dart'; // Importação obrigatória

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
  final VoidCallback? onRefresh;

  const UserListPage({super.key, this.onRefresh});

  @override
  State<UserListPage> createState() => UserListPageState();
}

class UserListPageState extends State<UserListPage>
    with WidgetsBindingObserver {
  Future<List<ChatItem>>? _combinedFuture;
  final User? currentUser = supabase.auth.currentUser;
  final TextEditingController _searchController = TextEditingController();
  String _searchTerm = '';

  // STREAM PARA RASTREAR STATUS ONLINE E TYPING
  late final Stream<List<Map<String, dynamic>>> _onlineStatusStream;

  // Mapa para rastrear is_online e is_typing: {user_id: {'online': true/false, 'typing': true/false}}
  Map<String, Map<String, bool>> _userStatusMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    loadData();
    _searchController.addListener(_onSearchChanged);
    _setupStatusStream();
    updateOnlineStatus(true);
  }

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

  Future<void> updateOnlineStatus(bool isOnline) async {
    if (currentUser == null) return;
    try {
      await supabase
          .from('profiles')
          .update({'is_online': isOnline}).eq('id', currentUser!.id);
    } catch (e) {
      print('Erro ao atualizar status online: $e');
    }
  }

  // CONFIGURAÇÃO DO STREAM PARA ESCUTAR ATUALIZAÇÕES DE STATUS
  void _setupStatusStream() {
    // Escuta is_online e is_typing
    _onlineStatusStream =
        supabase.from('profiles').stream(primaryKey: ['id']).map((data) {
      if (mounted) {
        setState(() {
          for (final row in data) {
            final id = row['id'] as String;
            final isOnline = row['is_online'] as bool? ?? false;
            final isTyping = row['is_typing'] as bool? ?? false;

            // Atualiza o mapa de status aninhado
            _userStatusMap[id] = {'online': isOnline, 'typing': isTyping};
          }
        });
      }
      return data;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      updateOnlineStatus(false);
    } else if (state == AppLifecycleState.resumed) {
      updateOnlineStatus(true);
    }
  }

  @override
  void dispose() {
    updateOnlineStatus(false);
    WidgetsBinding.instance.removeObserver(this);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ChatItem>> _fetchCombinedItems() async {
    final currentUserId = currentUser!.id;

    // 1. FETCH DOS PERFIS (Usuários) - Seleciona 'is_online' e 'is_typing'
    final profilesData = await supabase
        .from('profiles')
        .select('*, is_online, is_typing')
        .neq('id', currentUserId)
        .order('username', ascending: true);

    final profiles = (profilesData as List<dynamic>).map((user) {
      final String userId = user['id'] as String;
      final bool isOnline = user['is_online'] as bool? ?? false;
      final bool isTyping = user['is_typing'] as bool? ?? false;

      // Inicializa o mapa de status
      _userStatusMap[userId] = {'online': isOnline, 'typing': isTyping};

      return ChatItem(
        id: userId,
        title: user['username'] as String? ?? 'Usuário Sem Nome',
        avatarUrl: user['avatar_url'] as String?,
        isGroup: false,
        data: Map<String, dynamic>.from(user as Map),
      );
    }).toList();

    // 2. FETCH DOS GRUPOS (RPC) - (Mantido o código original)
    final groupsData = await supabase.rpc(
      'get_user_groups',
      params: {
        'user_id_input': currentUserId,
      },
    );

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
  Widget build(BuildContext context) {
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
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _onlineStatusStream,
            builder: (context, streamSnapshot) {
              return FutureBuilder<List<ChatItem>>(
                future: _combinedFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                        child: Text(
                            'Erro ao carregar contatos: ${snapshot.error}',
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

                      final Map<String, bool> status =
                          _userStatusMap[item.id] ??
                              {'online': false, 'typing': false};

                      final bool isOnline =
                          !item.isGroup && status['online'] == true;
                      final bool isTyping =
                          !item.isGroup && status['typing'] == true;

                      // Determina o Subtitle
                      String subtitleText;
                      Color subtitleColor;

                      if (item.isGroup) {
                        subtitleText = 'Grupo';
                        subtitleColor = Colors.greenAccent;
                      } else if (isTyping) {
                        subtitleText = 'Digitando...';
                        subtitleColor = Colors.lightBlueAccent;
                      } else if (isOnline) {
                        subtitleText = 'Online agora';
                        subtitleColor = Colors.grey;
                      } else {
                        subtitleText = 'Toque para iniciar a conversa';
                        subtitleColor = Colors.grey;
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 0, vertical: 2),
                        child: ListTile(
                          tileColor: Colors.transparent,
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: avatarColor,
                                backgroundImage: item.avatarUrl != null &&
                                        item.avatarUrl!.isNotEmpty
                                    ? NetworkImage(item.avatarUrl!)
                                    : null,
                                child: (item.avatarUrl == null ||
                                        item.avatarUrl!.isEmpty)
                                    ? Icon(leadingIcon,
                                        size: 30, color: Colors.white70)
                                    : null,
                              ),
                              // Indicador de status online
                              if (isOnline)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 15,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.black, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Text(item.title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text(
                            subtitleText,
                            style: TextStyle(color: subtitleColor),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios,
                              size: 16, color: Colors.grey),
                          onTap: () {
                            final Widget targetPage = item.isGroup
                                ? GroupChatPage(
                                    groupId: item.id, groupName: item.title)
                                : DirectMessagePage(
                                    recipientProfile: item.data,
                                    // Passa o status inicial para evitar lag
                                    isRecipientTyping: isTyping,
                                  );

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (context) => targetPage),
                            );
                          },
                        ),
                      );
                    },
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
