import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class GroupChatPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _messageController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  // Mapa para armazenar ID do usuário -> Nome de exibição (name_account)
  final Map<String, String> _usernames = {}; 
  final Map<String, List<String>> _reactions = {};
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    _messagesStream = supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: true);

    _loadUsernames();
    _listenReactions();
  }

  // 🔥 STREAM DE REAÇÕES (Sem alteração)
  void _listenReactions() {
    supabase
        .from('group_reactions')
        .stream(primaryKey: ['id'])
        .listen((event) {
      _syncReactions();
    });

    _syncReactions();
  }

  Future<void> _syncReactions() async {
    final resp = await supabase.from('group_reactions').select();

    final Map<String, List<String>> newMap = {};

    for (final r in resp) {
      final messageId = r['message_id'];
      final emoji = r['emoji'];

      newMap.putIfAbsent(messageId, () => []);
      newMap[messageId]!.add(emoji);
    }

    setState(() => _reactions
      ..clear()
      ..addAll(newMap));
  }

  // 🎯 CORREÇÃO 1: Carregar 'name_account' e usar 'username' como fallback
  Future<void> _loadUsernames() async {
    final profiles = await supabase.from('profiles').select('id, name_account, username');

    for (final p in profiles) {
      final String displayName = p['name_account'] ?? p['username'] ?? 'Desconhecido';
      _usernames[p['id']] = displayName;
    }

    if (mounted) setState(() {});
  }

  Future<void> _sendMessage({String? content, String? imageUrl}) async {
    final text = content?.trim() ?? _messageController.text.trim();
    if ((text.isEmpty && imageUrl == null)) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _messageController.clear();

    try {
      await supabase.from('group_messages').insert({
        'group_id': widget.groupId,
        'sender_id': userId,
        'content': text,
        'image_url': imageUrl,
      });
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao enviar mensagem: $e')));
    }
  }

  // 🔥 ENVIO DE IMAGEM (Sem alteração)
  Future<void> _pickAndSendImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (picked == null) return;

    final Uint8List fileBytes = await picked.readAsBytes();
    final String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    setState(() => _isSending = true);

    try {
      await supabase.storage.from('chat-images').uploadBinary(
            fileName,
            fileBytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: false),
          );

      final String imageUrl =
          supabase.storage.from('chat-images').getPublicUrl(fileName);

      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro ao enviar imagem: $e")));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // 🔥 SOMENTE UMA REAÇÃO POR USUÁRIO (Sem alteração)
  void _addReaction(String messageId, String emoji) async {
    final userId = supabase.auth.currentUser!.id;

    try {
      await supabase
          .from('group_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);

      await supabase.from('group_reactions').insert({
        'message_id': messageId,
        'user_id': userId,
        'emoji': emoji,
      });
    } catch (e) {
      print("Erro ao salvar reação: $e");
    }
  }

  Future<void> _showReactionsDialog(String messageId) async {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '👏'];

    final emoji = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Escolha uma reação'),
        content: Wrap(
          spacing: 10,
          children: emojis
              .map((e) => GestureDetector(
                    onTap: () => Navigator.pop(context, e),
                    child: Text(e, style: const TextStyle(fontSize: 30)),
                  ))
              .toList(),
        ),
      ),
    );

    if (emoji != null) _addReaction(messageId, emoji);
  }

  // 🔥 MOSTRAR INTEGRANTES DO GRUPO
  Future<void> _showMembers() async {
    try {
      // Buscar apenas user_id
      final members = await supabase
          .from('group_members')
          .select('user_id')
          .eq('group_id', widget.groupId);

      final List memList = members as List? ?? [];

      // Buscar name_account
      List<Map<String, dynamic>> detailed = [];

      for (final m in memList) {
        final userId = m['user_id'];

        // 🎯 CORREÇÃO 2: Buscar 'name_account' e 'username'
        final profile = await supabase
            .from('profiles')
            .select('name_account, username') 
            .eq('id', userId)
            .maybeSingle();
        
        // Define o nome de exibição: name_account ou username(email) como fallback
        final String displayName = 
          profile?['name_account'] as String? ?? 
          profile?['username'] as String? ?? 
          'Desconhecido';

        detailed.add({
          'user_id': userId,
          // 🎯 CORREÇÃO 3: Usar o nome de exibição
          'display_name': displayName, 
        });
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Integrantes do grupo"),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: detailed.length,
              itemBuilder: (_, i) {
                final m = detailed[i];
                final String name = m['display_name'] as String;
                final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return ListTile(
                  leading: CircleAvatar(
                    // 🎯 CORREÇÃO 4: Usar a primeira letra do nome de exibição
                    child: Text(firstLetter), 
                  ),
                  // 🎯 CORREÇÃO 5: Exibir o nome de exibição
                  title: Text(name), 
                  subtitle: Text(m['user_id']),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Fechar"),
            )
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao carregar membros: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          // 🔥 BOTÃO DE MEMBROS
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _showMembers,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg['sender_id'] == myId;
                    
                    // O `_usernames` agora contém o `name_account`
                    final username =
                        _usernames[msg['sender_id']] ?? 'Carregando...';
                    final messageId = msg['id'].toString();

                    return GestureDetector(
                      onTap: () => _showReactionsDialog(messageId),
                      child: _GroupBubble(
                        message: msg['content'],
                        imageUrl: msg['image_url'],
                        username: username,
                        isMe: isMe,
                        reactions: _reactions[messageId] ?? [],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Campo de texto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: const Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image,
                      color: _isSending ? Colors.grey : Colors.green),
                  onPressed: _isSending ? null : _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration.collapsed(
                        hintText: 'Mensagem...'),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _isSending ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupBubble extends StatelessWidget {
  final String? message;
  final String? imageUrl;
  final String username; // Já está correto, pois recebe o dado de _usernames
  final bool isMe;
  final List<String> reactions;

  const _GroupBubble({
    this.message,
    this.imageUrl,
    required this.username,
    required this.isMe,
    required this.reactions,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[200] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
        ),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              username,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isMe ? Colors.green[900] : Colors.black87,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!, style: const TextStyle(fontSize: 15)),
            ],
            if (imageUrl != null) ...[
              const SizedBox(height: 6),
              Image.network(imageUrl!),
            ],
            if (reactions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: reactions
                    .map((e) => Text(e, style: const TextStyle(fontSize: 16)))
                    .toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }
}