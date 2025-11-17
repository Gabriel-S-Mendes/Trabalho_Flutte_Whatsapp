import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'main.dart'; // Certifique-se de que supabase está inicializado aqui

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

  // Cache simples de usernames
  final Map<String, String> _usernames = {};
  final Map<String, List<String>> _reactions = {}; // messageId -> lista de emojis
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Escuta mensagens em tempo real do grupo
    _messagesStream = supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: true);

    _loadUsernames();
  }

  Future<void> _loadUsernames() async {
    final profiles = await supabase.from('profiles').select('id, username');

    for (final p in profiles) {
      _usernames[p['id']] = p['username'] ?? 'Desconhecido';
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

  Future<void> _pickAndSendImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final file = File(image.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';

    try {
      await supabase.storage.from('chat-images').upload(fileName, file);
      final imageUrl = supabase.storage.from('chat-images').getPublicUrl(fileName);

      _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao enviar imagem: $e')));
    }
  }

  void _addReaction(String messageId, String emoji) async {
    final reactionsList = _reactions[messageId] ?? [];
    reactionsList.add(emoji);

    setState(() {
      _reactions[messageId] = reactionsList;
    });

    // Salvar no Supabase (em grupo_reactions)
    try {
      await supabase.from('group_reactions').insert({
        'message_id': messageId,
        'user_id': supabase.auth.currentUser!.id,
        'emoji': emoji,
      });
    } catch (e) {
      print('Erro ao salvar reação: $e');
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
                    child: Text(
                      e,
                      style: const TextStyle(fontSize: 30),
                    ),
                  ))
              .toList(),
        ),
      ),
    );

    if (emoji != null) _addReaction(messageId, emoji);
  }

  Future<void> _showGroupMembers() async {
    final members = await supabase
        .from('group_members')
        .select('user_id, profiles(username)')
        .eq('group_id', widget.groupId);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Membros do grupo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: (members as List)
              .map((m) => ListTile(
                    title: Text(m['profiles']['username'] ?? 'Desconhecido'),
                  ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: _showGroupMembers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Lista de mensagens
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg['sender_id'] == myId;
                    final username = _usernames[msg['sender_id']] ?? 'Carregando...';
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
                  icon: const Icon(Icons.image, color: Colors.green),
                  onPressed: _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration:
                        const InputDecoration.collapsed(hintText: 'Mensagem...'),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _sendMessage,
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
  final String username;
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
                children: reactions.map((e) => Text(e, style: const TextStyle(fontSize: 16))).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
