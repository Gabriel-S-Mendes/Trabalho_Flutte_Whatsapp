import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

// 🎯 Widget de Exibição de Mensagem Individual
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.sentAt,
    this.imageUrl,
  });

  final String? message;
  final bool isCurrentUser;
  final DateTime sentAt;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCurrentUser
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade700,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isCurrentUser
                    ? const Radius.circular(16)
                    : const Radius.circular(2),
                bottomRight: isCurrentUser
                    ? const Radius.circular(2)
                    : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message != null)
                  Text(message!, style: const TextStyle(color: Colors.white)),
                if (imageUrl != null) ...[
                  const SizedBox(height: 4),
                  Image.network(imageUrl!),
                ],
                const SizedBox(height: 4),
                Text(
                  "${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')} ${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white70 : Colors.grey.shade300,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 💬 Tela Principal de Mensagem Direta
class DirectMessagePage extends StatefulWidget {
  const DirectMessagePage({
    super.key,
    required this.recipientProfile,
  });

  final Map<String, dynamic> recipientProfile;

  @override
  State<DirectMessagePage> createState() => _DirectMessagePageState();
}

class _DirectMessagePageState extends State<DirectMessagePage> {
  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  final TextEditingController _textController = TextEditingController();
  final User? currentUser = supabase.auth.currentUser;
  late final ScrollController _scrollController;
  late final String currentUserId;
  late final String recipientId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    if (currentUser == null) return;

    currentUserId = currentUser!.id;
    recipientId = widget.recipientProfile['id'] as String;
    _scrollController = ScrollController();

    // 🔹 Stream de mensagens de TODOS, filtrado localmente
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true);
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final text = _textController.text.trim();
    _textController.clear();

    try {
      await supabase.from('messages').insert({
        'sender_id': currentUserId,
        'recipient_id': recipientId,
        'content': text,
        'image_url': null,
      });

      _scrollToBottom();
    } on PostgrestException catch (e) {
      if (mounted) _showSnackBar(context, 'Erro ao enviar mensagem: ${e.message}');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (picked == null) return;

    final Uint8List fileBytes = await picked.readAsBytes();
    final String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    setState(() => _isSending = true);

    try {
      // Upload da imagem
      await supabase.storage.from('chat-images').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: false),
          );

      final String imageUrl =
          supabase.storage.from('chat-images').getPublicUrl(fileName);

      await supabase.from('messages').insert({
        'sender_id': currentUserId,
        'recipient_id': recipientId,
        'content': null,
        'image_url': imageUrl,
      });

      _scrollToBottom();
    } catch (e) {
      _showSnackBar(context, "Erro ao enviar imagem: $e");
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

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipientUsername =
        widget.recipientProfile['username'] as String? ?? 'Usuário Desconhecido';
    final recipientOnline = widget.recipientProfile['is_online'] as bool? ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(recipientUsername),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 6,
              backgroundColor: recipientOnline ? Colors.green : Colors.grey,
            ),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erro de conexão: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final raw = snapshot.data ?? [];
                final messages = raw.where((m) {
                  final s = m['sender_id']?.toString();
                  final r = m['recipient_id']?.toString();
                  return (s == currentUserId && r == recipientId) ||
                      (s == recipientId && r == currentUserId);
                }).toList();

                _scrollToBottom();

                if (messages.isEmpty) {
                  return Center(
                    child: Text('Inicie uma conversa com $recipientUsername!'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index];
                    final content = messageData['content'] as String?;
                    final senderId = messageData['sender_id'] as String;
                    final sentAt = DateTime.parse(messageData['created_at'] as String);
                    final imageUrl = messageData['image_url'] as String?;
                    final isCurrentUserMessage = senderId == currentUserId;

                    return ChatBubble(
                      message: content,
                      isCurrentUser: isCurrentUserMessage,
                      sentAt: sentAt.toLocal(),
                      imageUrl: imageUrl,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isSending ? null : _sendImage,
                  icon: const Icon(Icons.image),
                  tooltip: 'Enviar imagem',
                ),
                Expanded(
                  child: TextFormField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Digite sua mensagem...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade800,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: Icon(
                    Icons.send,
                    color: _isSending ? Colors.grey : Theme.of(context).primaryColor,
                  ),
                  tooltip: 'Enviar Mensagem',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
