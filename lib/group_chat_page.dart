import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  final Map<String, String> _usernames = {};
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await supabase.from('group_messages').insert({
        'group_id': widget.groupId,
        'sender_id': userId,
        'content': text,
        'image_url': null,
      });

      _scrollToBottom();
    } catch (e) {
      _showSnackBar('Erro ao enviar mensagem: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_isSending) return;

    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (picked == null) return;

    final Uint8List fileBytes = await picked.readAsBytes();
    final String fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${picked.name}";
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isSending = true);

    try {
      await supabase.storage.from('chat-images').uploadBinary(fileName, fileBytes);

      final String imageUrl =
          supabase.storage.from('chat-images').getPublicUrl(fileName);

      await supabase.from('group_messages').insert({
        'group_id': widget.groupId,
        'sender_id': userId,
        'content': null,
        'image_url': imageUrl,
      });

      _scrollToBottom();
    } catch (e) {
      _showSnackBar('Erro ao enviar imagem: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // Função para mostrar integrantes do grupo
  Future<void> _showGroupMembers() async {
    try {
      final List members = await supabase
          .from('group_members')
          .select('user_id')
          .eq('group_id', widget.groupId);

      final List<String> memberNames = [];
      for (var m in members) {
        final username = _usernames[m['user_id']] ?? 'Desconhecido';
        memberNames.add(username);
      }

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Integrantes do grupo'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: memberNames.length,
              itemBuilder: (_, index) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(memberNames[index]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackBar('Erro ao carregar membros: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _showGroupMembers,
            tooltip: 'Ver integrantes',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg['sender_id'] == myId;
                    final username =
                        _usernames[msg['sender_id']] ?? 'Carregando...';

                    return _GroupBubble(
                      message: msg['content'],
                      imageUrl: msg['image_url'],
                      username: username,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: const Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.blue),
                  onPressed: _isSending ? null : _sendImage,
                  tooltip: 'Enviar imagem',
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
                  icon: Icon(Icons.send,
                      color: _isSending ? Colors.grey : Colors.green),
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
  final String username;
  final bool isMe;

  const _GroupBubble({
    this.message,
    this.imageUrl,
    required this.username,
    required this.isMe,
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
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(message!, style: const TextStyle(fontSize: 15)),
            ],
            if (imageUrl != null && imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Image.network(imageUrl!),
            ],
          ],
        ),
      ),
    );
  }
}
