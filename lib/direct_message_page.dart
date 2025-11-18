import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'dart:async';

// ----------------------------------------------------------
// 🟦 WIDGET DE BOLHA DE MENSAGEM (Sem alterações)
// ----------------------------------------------------------
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.imageUrl,
    required this.isCurrentUser,
    required this.sentAt,
    this.reactions = const [],
  });

  final String? message;
  final String? imageUrl;
  final bool isCurrentUser;
  final DateTime sentAt;
  final List<String> reactions;

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
                if (imageUrl != null)
                  Padding(
                    padding: message != null
                        ? const EdgeInsets.only(bottom: 8.0)
                        : EdgeInsets.zero,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                      ),
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
                // Exibir reações
                if (reactions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    children: reactions
                        .map((e) =>
                            Text(e, style: const TextStyle(fontSize: 16)))
                        .toList(),
                  ),
                ]
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
  final Map<String, dynamic> recipientProfile;
  final bool isRecipientTyping;

  const DirectMessagePage({
    super.key,
    required this.recipientProfile,
    this.isRecipientTyping = false,
  });

  @override
  State<DirectMessagePage> createState() => _DirectMessagePageState();
}

class _DirectMessagePageState extends State<DirectMessagePage> {
  final TextEditingController _textController = TextEditingController();
  final User? currentUser = supabase.auth.currentUser;
  final ScrollController _scrollController = ScrollController();

  late final Stream<List<Map<String, dynamic>>> _messagesStream;
  final Map<String, List<String>> _reactions = {};

  // 🔥 CORREÇÃO REALTIME: Usa StreamSubscription para cancelar o listener (sem o .on())
  late final StreamSubscription<List<Map<String, dynamic>>>
      _reactionsSubscription;

  Timer? _typingTimer;
  bool _isTypingLocally = false;
  late final Stream<Map<String, dynamic>> _recipientStatusStream;

  late final String currentUserId;
  late final String recipientId;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();

    currentUserId = currentUser!.id;
    recipientId = widget.recipientProfile['id'] as String;

    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id']).order('created_at', ascending: true);

    _recipientStatusStream = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', recipientId)
        .map((dataList) {
          if (dataList.isNotEmpty) {
            return dataList.first;
          }
          return {};
        });

    _listenReactions();
  }

  // ----------------------------------------------------------
  // 🔥 REAÇÕES DM: Lógica de Realtime e Sincronização (Corrigida)
  // ----------------------------------------------------------

  void _listenReactions() {
    // 🔥 CORREÇÃO REALTIME: Volta para a sintaxe stream().listen()
    // Isso garante a compatibilidade e a atualização em tempo real
    _reactionsSubscription = supabase
        .from('message_reactions')
        .stream(primaryKey: ['id']).listen((event) {
      _syncReactions();
    });

    _syncReactions(); // Carrega as reações iniciais
  }

  Future<void> _syncReactions() async {
    final resp = await supabase.from('message_reactions').select();

    final Map<String, List<String>> newMap = {};

    for (final r in resp) {
      final messageId = r['message_id'].toString();
      final emoji = r['emoji'] as String;

      newMap.putIfAbsent(messageId, () => []);
      newMap[messageId]!.add(emoji);
    }

    if (mounted) {
      setState(() => _reactions
        ..clear()
        ..addAll(newMap));
    }
  }

  void _addReaction(String messageId, String emoji) async {
    final userId = supabase.auth.currentUser!.id;

    try {
      // 1. DELETE (UPSERT): Remove a reação existente do usuário
      await supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', int.parse(messageId))
          .eq('user_id', userId);

      // 2. INSERT: Adiciona a nova reação
      await supabase.from('message_reactions').insert({
        'message_id': int.parse(messageId),
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

  // ----------------------------------------------------------
  // LÓGICA DE DEBOUNCE, ENVIO DE MENSAGEM, ENVIO DE IMAGEM (Mantidas)
  // ----------------------------------------------------------
  Future<void> _setIsTyping(bool isTyping) async {
    if (currentUser == null || _isTypingLocally == isTyping) return;

    _isTypingLocally = isTyping;

    try {
      await supabase
          .from('profiles')
          .update({'is_typing': isTyping}).eq('id', currentUser!.id);
    } catch (e) {
      print('Erro ao atualizar status de digitação: $e');
    }
  }

  void _handleTyping(String text) {
    final currentText = text.trim();

    if (currentText.isNotEmpty) {
      _setIsTyping(true);

      if (_typingTimer?.isActive ?? false) {
        _typingTimer!.cancel();
      }

      _typingTimer = Timer(const Duration(milliseconds: 1500), () {
        if (_textController.text.trim().isEmpty) {
          _setIsTyping(false);
        }
      });
    } else {
      _setIsTyping(false);
      _typingTimer?.cancel();
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    _setIsTyping(false);
    _typingTimer?.cancel();

    setState(() => _isSending = true);

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

  Future<void> _sendImage() async {
    final picker = ImagePicker();

    final XFile? picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);

    if (picked == null) return;

    final fileName =
        "${DateTime.now().millisecondsSinceEpoch}_${currentUserId}.jpg";

    try {
      Uint8List bytes = await picked.readAsBytes();

      await supabase.storage.from('chat-images').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      final imageUrl =
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
    }
  }

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

  @override
  void dispose() {
    _setIsTyping(false);
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();

    // 🔥 CORREÇÃO REALTIME: Cancela a inscrição do Stream
    _reactionsSubscription.cancel();

    super.dispose();
  }

  // ----------------------------------------------------------
  // 🖥 INTERFACE
  // ----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // 🎯 CORREÇÃO: Puxa 'name_account' e usa 'username' como fallback
    final displayName = widget.recipientProfile['name_account'] as String? ?? 
                        widget.recipientProfile['username'] as String? ?? 'Usuário Desconhecido';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: CircleAvatar(
                backgroundColor: Colors.blueGrey.shade700,
                backgroundImage:
                    widget.recipientProfile['avatar_url'] != null &&
                            widget.recipientProfile['avatar_url'].isNotEmpty
                        ? NetworkImage(widget.recipientProfile['avatar_url'])
                        : null,
                child: (widget.recipientProfile['avatar_url'] == null ||
                        widget.recipientProfile['avatar_url'].isEmpty)
                    ? const Icon(Icons.person, size: 20, color: Colors.white70)
                    : null,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🎯 CORREÇÃO: Usa displayName em vez de username
                Text(displayName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                StreamBuilder<Map<String, dynamic>>(
                  stream: _recipientStatusStream,
                  initialData: {
                    'is_online': widget.recipientProfile['is_online'] ?? false,
                    'is_typing': widget.isRecipientTyping
                  },
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? {};
                    final bool isOnline = data['is_online'] == true;
                    final bool isTyping = data['is_typing'] == true;

                    String statusText;
                    Color statusColor;

                    if (isTyping) {
                      statusText = 'Digitando...';
                      statusColor = Colors.lightBlueAccent;
                    } else if (isOnline) {
                      statusText = 'Online agora';
                      statusColor = Colors.greenAccent;
                    } else {
                      statusText = 'Offline';
                      statusColor = Colors.grey;
                    }

                    return Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 13,
                        color: statusColor,
                        fontWeight: FontWeight.normal,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                final rawMessages = snapshot.data ?? [];

                final messages = rawMessages.where((m) {
                  final s = m['sender_id'];
                  final r = m['recipient_id'];

                  return (s == currentUserId && r == recipientId) ||
                      (s == recipientId && r == currentUserId);
                }).toList();

                if (!snapshot.hasData &&
                    snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m['sender_id'] == currentUserId;
                    final messageId = m['id'].toString();

                    return GestureDetector(
                      onTap: () => _showReactionsDialog(messageId),
                      child: ChatBubble(
                        message: m['content'],
                        imageUrl: m['image_url'],
                        isCurrentUser: isMe,
                        sentAt:
                            DateTime.parse(m['created_at'] as String).toLocal(),
                        reactions: _reactions[messageId] ?? [],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: 8.0,
              right: 8.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 8.0,
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sendImage,
                  icon: const Icon(Icons.image, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _textController,
                    onChanged: _handleTyping,
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
