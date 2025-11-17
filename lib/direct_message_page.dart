import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

// ----------------------------------------------------------
// 🟦 WIDGET DE BOLHA DE MENSAGEM (TEXTO + IMAGEM)
// ----------------------------------------------------------
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.imageUrl,
    required this.isCurrentUser,
    required this.sentAt,
  });

  final String? message;
  final String? imageUrl;
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
                bottomLeft:
                    isCurrentUser ? const Radius.circular(16) : const Radius.circular(2),
                bottomRight:
                    isCurrentUser ? const Radius.circular(2) : const Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (message != null)
                  Text(
                    message!,
                    style: const TextStyle(color: Colors.white),
                  ),
                const SizedBox(height: 4),
                Text(
                  "${sentAt.day.toString().padLeft(2, '0')}/${sentAt.month.toString().padLeft(2, '0')} "
                  "${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}",
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

// ----------------------------------------------------------
// 🔵 TELA DE MENSAGENS DIRETAS
// ----------------------------------------------------------
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

    currentUserId = currentUser!.id;
    recipientId = widget.recipientProfile['id'] as String;

    _scrollController = ScrollController();

    // STREAM: recebe apenas mensagens onde o usuário é o sender
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('sender_id', currentUserId)
        .order('created_at', ascending: true);
  }

  // ----------------------------------------------------------
  // ✉ ENVIO DE TEXTO
  // ----------------------------------------------------------
  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await supabase.from('messages').insert({
        'sender_id': currentUserId,
        'recipient_id': recipientId,
        'content': text,
        'image_url': null,
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ----------------------------------------------------------
  // 🖼 ENVIO DE IMAGEM (WEB + MOBILE + DESKTOP)
  // ----------------------------------------------------------
  Future<void> _sendImage() async {
    final picker = ImagePicker();

    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (picked == null) return;

    final fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${currentUserId}.jpg";

    try {
      // Carregar bytes (compatível com qualquer plataforma)
      Uint8List bytes = await picked.readAsBytes();

      // Enviar para o Supabase Storage
      await supabase.storage.from('chat-images').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // Obter URL pública
      final imageUrl =
          supabase.storage.from('chat-images').getPublicUrl(fileName);

      // Inserir mensagem com imagem
      await supabase.from('messages').insert({
        'sender_id': currentUserId,
        'recipient_id': recipientId,
        'content': null,
        'image_url': imageUrl,
      });

      _scrollToBottom();
    } catch (e) {
      _showSnackBar(context, "Erro ao enviar imagem: $e");
    }
  }

  // ----------------------------------------------------------
  // 🔽 SCROLL PARA BAIXO
  // ----------------------------------------------------------
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  // ----------------------------------------------------------
  // 🖥 INTERFACE
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final username =
        widget.recipientProfile['username'] ?? "Usuário Desconhecido";

    return Scaffold(
      appBar: AppBar(title: Text(username)),
      body: Column(
        children: [
          // ---------------- MENSAGENS ----------------
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                final rawMessages = snapshot.data ?? [];

                // Filtrar mensagens de ambos os lados
                final messages = rawMessages.where((m) {
                  final s = m['sender_id'];
                  final r = m['recipient_id'];

                  return (s == currentUserId && r == recipientId) ||
                      (s == recipientId && r == currentUserId);
                }).toList();

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m['sender_id'] == currentUserId;

                    return ChatBubble(
                      message: m['content'],
                      imageUrl: m['image_url'],
                      isCurrentUser: isMe,
                      sentAt: DateTime.parse(m['created_at']).toLocal(),
                    );
                  },
                );
              },
            ),
          ),

          // ---------------- CAMPO DE ENVIO ----------------
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Botão de enviar imagem
                IconButton(
                  onPressed: _sendImage,
                  icon: const Icon(Icons.image, color: Colors.white),
                ),
                const SizedBox(width: 8),

                // Campo de texto
                Expanded(
                  child: TextFormField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Digite sua mensagem...",
                      filled: true,
                      fillColor: Colors.grey.shade800,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Botão de enviar texto
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: Icon(
                    Icons.send,
                    color: _isSending
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
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
