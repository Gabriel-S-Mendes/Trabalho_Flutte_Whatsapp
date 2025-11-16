import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

// 🎯 Widget de Exibição de Mensagem Individual
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    required this.sentAt,
  });

  final String message;
  final bool isCurrentUser;
  final DateTime sentAt;

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
                maxWidth: MediaQuery.of(context).size.width * 0.75),
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
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  // Exibe data/hora simples
                  "${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')} ${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color:
                        isCurrentUser ? Colors.white70 : Colors.grey.shade300,
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

    if (currentUser == null) {
      _messagesStream = const Stream.empty();
      return;
    }

    currentUserId = currentUser!.id;
    recipientId = widget.recipientProfile['id'] as String;
    _scrollController = ScrollController();

    _messagesStream = supabase
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .or(
          'sender_id.eq.$currentUserId,recipient_id.eq.$recipientId|sender_id.eq.$recipientId,recipient_id.eq.$currentUserId',
        )
        .order('created_at', ascending: true);
  }

  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final text = _textController.text.trim();
    _textController.clear();

    try {
      await supabase.from('direct_messages').insert({
        'sender_id': currentUserId,
        'recipient_id': recipientId,
        'content': text,
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    } on PostgrestException catch (e) {
      if (mounted) {
        _showSnackBar(context, 'Erro ao enviar mensagem: ${e.message}');
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
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
    final recipientUsername = widget.recipientProfile['username'] as String? ??
        'Usuário Desconhecido';

    return Scaffold(
      appBar: AppBar(
        title: Text(recipientUsername),
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

                final messages = snapshot.data ?? [];

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

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
                    final content = messageData['content'] as String;
                    final senderId = messageData['sender_id'] as String;
                    final sentAt =
                        DateTime.parse(messageData['created_at'] as String);
                    final isCurrentUserMessage = senderId == currentUserId;

                    return ChatBubble(
                      message: content,
                      isCurrentUser: isCurrentUserMessage,
                      sentAt: sentAt.toLocal(),
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
                          horizontal: 20, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: Icon(
                    Icons.send,
                    color: _isSending
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
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
