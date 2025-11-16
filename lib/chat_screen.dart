import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Para acessar o cliente 'supabase'

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  // Recebe o ID e o Nome da sala ao navegar (vindo da HomePage)
  const ChatScreen({super.key, required this.roomId, required this.roomName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();

  // O StreamListener é usado para ouvir mensagens em tempo real
  late final Stream<List<Map<String, dynamic>>> _messagesStream;

  // Map para armazenar os usernames e evitar buscas repetidas
  final Map<String, String> _usernames = {};

  @override
  void initState() {
    super.initState();
    // 1. Configura a escuta em tempo real:
    _messagesStream = supabase
        .from('messages')
        .stream(primaryKey: ['id']) // Ponto de escuta no Supabase
        .eq('room_id',
            widget.roomId) // Filtra para mostrar apenas mensagens desta sala
        .order('created_at',
            ascending: true); // Ordena da mais antiga para a mais nova

    // 2. Pré-carrega os usernames para exibição
    _loadUsernames();
  }

  // Função para buscar os usernames dos perfis envolvidos
  Future<void> _loadUsernames() async {
    // Busca todos os perfis existentes
    final profiles = await supabase.from('profiles').select('id, username');

    // Mapeia o id para o username para fácil acesso
    for (final profile in profiles) {
      _usernames[profile['id']] = profile['username'] ?? 'Desconhecido';
    }
    // Força a reconstrução do widget para mostrar os usernames
    if (mounted) {
      setState(() {});
    }
  }

  // Função para enviar uma nova mensagem
  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    _messageController.clear(); // Limpa o campo imediatamente

    final userId = supabase.auth.currentUser!.id;

    try {
      // Insere a mensagem na tabela 'messages'
      await supabase.from('messages').insert({
        'room_id': widget.roomId,
        'profile_id': userId,
        'content': content,
      });
      // O Realtime fará o resto, atualizando a lista automaticamente.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar mensagem: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ID do usuário logado para saber se a mensagem é dele
    final currentUserId = supabase.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
      ),
      body: Column(
        children: [
          // ------------------------------------------------
          // A. Lista de Mensagens (Usando StreamBuilder para Realtime)
          // ------------------------------------------------
          Expanded(
            // StreamBuilder ouve as mudanças em tempo real!
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                // Exibe a lista de mensagens invertida (mensagens novas embaixo)
                return ListView.builder(
                  reverse:
                      true, // Começa do fim da lista (mensagens mais recentes)
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    // Pega a mensagem do final da lista (mais recente)
                    final message = messages[messages.length - 1 - index];
                    final isMine = message['profile_id'] == currentUserId;

                    final username =
                        _usernames[message['profile_id']] ?? 'Carregando...';

                    return ChatBubble(
                      message: message['content'],
                      username: username,
                      isMe: isMine,
                    );
                  },
                );
              },
            ),
          ),

          // ------------------------------------------------
          // B. Campo de Texto para Envio
          // ------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: const Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Digite uma mensagem...',
                    ),
                    onSubmitted: (_) =>
                        _sendMessage(), // Envia ao apertar Enter
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

// Widget simples para exibir a bolha de chat
class ChatBubble extends StatelessWidget {
  final String message;
  final String username;
  final bool isMe;

  const ChatBubble({
    super.key,
    required this.message,
    required this.username,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        padding: const EdgeInsets.all(10.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[200] : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Username (aparece em cor diferente se não for você)
            Text(
              username,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isMe ? Colors.green[800] : Colors.blueGrey[800],
              ),
            ),
            const SizedBox(height: 4),
            // Conteúdo da Mensagem
            Text(
              message,
              style: TextStyle(
                color: isMe ? Colors.black87 : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
