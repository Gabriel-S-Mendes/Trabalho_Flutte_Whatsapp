import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'package:timeago/timeago.dart' as timeago;

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
                    color: isCurrentUser ? Colors.white : Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(sentAt, locale: 'pt'),
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

  // O perfil do usuário com quem estamos conversando.
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

  // Variável para evitar o reenvio rápido
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Verifica se o usuário atual está logado
    if (currentUser == null) {
      // Se não estiver logado, não há stream de mensagens
      _messagesStream = const Stream.empty();
      return;
    }

    currentUserId = currentUser!.id;
    recipientId = widget.recipientProfile['id'] as String;
    _scrollController = ScrollController();

    // 1. A consulta de mensagens privadas é mais complexa:
    //    Ela precisa retornar mensagens onde (sender_id = A E recipient_id = B)
    //    OU (sender_id = B E recipient_id = A)
    //    Para o Supabase, isso é feito com filtros `or`.
    _messagesStream = supabase
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        // Filtrar mensagens onde:
        // (sender_id = currentUserId E recipient_id = recipientId)
        // OU
        // (sender_id = recipientId E recipient_id = currentUserId)
        .or(
          'sender_id.eq.$currentUserId,recipient_id.eq.$currentUserId', // Bloco A: Eu sou o remetente OU o destinatário
          'sender_id.eq.$recipientId,recipient_id.eq.$recipientId', // Bloco B: O outro é o remetente OU o destinatário
        )
        // Isso retorna TODAS as mensagens entre os dois IDs.
        .order('created_at', ascending: true);
  }

  // 💬 Função para enviar uma nova mensagem
  Future<void> _sendMessage() async {
    if (_textController.text.trim().isEmpty || _isSending) {
      return; // Não envia se o campo estiver vazio ou se já estiver enviando
    }

    setState(() {
      _isSending = true; // Define como 'enviando'
    });

    final text = _textController.text.trim();
    _textController.clear(); // Limpa o campo de texto imediatamente

    try {
      await supabase.from('direct_messages').insert({
        'sender_id': currentUserId,
        'recipient_id': recipientId,
        'content': text,
      });

      // Rola para o final da lista após o envio
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
      if (mounted) {
        setState(() {
          _isSending = false; // Permite o próximo envio
        });
      }
    }
  }

  // 🔔 Função auxiliar para exibir SnackBar
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
    final String recipientUsername =
        widget.recipientProfile['username'] as String? ??
            'Usuário Desconhecido';

    return Scaffold(
      appBar: AppBar(
        title: Text(recipientUsername),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 1,
      ),
      body: Column(
        children: [
          // 2. Visualização das Mensagens em Tempo Real
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                      child: Text('Erro de conexão: ${snapshot.error}',
                          style: const TextStyle(color: Colors.redAccent)));
                }

                final messages = snapshot.data ?? [];

                // 💡 Rola automaticamente para o final da lista na primeira carga ou quando novas mensagens chegam.
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
                    final String content = messageData['content'] as String;
                    final String senderId = messageData['sender_id'] as String;
                    final DateTime sentAt =
                        DateTime.parse(messageData['created_at'] as String);

                    final bool isCurrentUserMessage = senderId == currentUserId;

                    return ChatBubble(
                      message: content,
                      isCurrentUser: isCurrentUserMessage,
                      sentAt: sentAt.toLocal(), // Exibir horário local
                    );
                  },
                );
              },
            ),
          ),
          // 3. Campo de Entrada para Nova Mensagem
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
                    maxLines: null, // Permite múltiplas linhas
                  ),
                ),
                const SizedBox(width: 8),
                // Botão de Envio
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: Icon(
                    Icons.send,
                    color: _isSending
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
                  ),
                  // Se estiver enviando, mostra um loader no lugar do ícone
                  // ou desabilita o botão
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
