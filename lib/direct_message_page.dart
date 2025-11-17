import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Importe a variável global 'supabase'
import 'dart:async'; // Necessário para o Timer (debounce)

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
  final User? currentUser = supabase.auth.currentUser;
  final TextEditingController _messageController = TextEditingController();

  // Variáveis para controle de debounce e status local
  Timer? _typingTimer;
  bool _isTypingLocally = false;

  // Stream para rastrear o status de digitação do destinatário em tempo real
  late final Stream<Map<String, dynamic>> _recipientStatusStream;

  @override
  void initState() {
    super.initState();
    final recipientId = widget.recipientProfile['id'] as String;

    // SINTAXE CORRIGIDA: Removendo .select() e .limit(1) para evitar o erro.
    // O stream agora retorna o payload completo da linha do perfil.
    _recipientStatusStream = supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', recipientId)
        .map((dataList) {
          // O Supabase Realtime retorna uma lista de dados (dataList).
          // Retornamos o primeiro item, que contém os campos 'is_online' e 'is_typing'.
          if (dataList.isNotEmpty) {
            return dataList.first;
          }
          return {};
        });
  }

  // MÉTODO PARA ATUALIZAR O STATUS DE DIGITAÇÃO DO USUÁRIO LOCAL NO SUPABASE
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

  // LÓGICA DE DEBOUNCE
  void _handleTyping(String text) {
    if (text.trim().isNotEmpty) {
      // 1. Seta o status para TRUE imediatamente
      _setIsTyping(true);

      // 2. Reseta o timer (debounce)
      if (_typingTimer?.isActive ?? false) {
        _typingTimer!.cancel();
      }

      // 3. Cria um novo timer: se expirar (1.5s), seta o status para FALSE
      _typingTimer = Timer(const Duration(milliseconds: 1500), () {
        _setIsTyping(false);
      });
    } else {
      // Campo vazio, seta imediatamente para FALSE e cancela o timer
      _setIsTyping(false);
      _typingTimer?.cancel();
    }
  }

  // Lógica de envio da mensagem
  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    // TODO: Implementar a lógica de inserção da mensagem aqui

    _messageController.clear();

    // Importante: Reseta o status de digitação para FALSE após o envio
    _setIsTyping(false);
    _typingTimer?.cancel();
  }

  @override
  void dispose() {
    // Garante que o status 'is_typing' seja FALSE ao sair da tela
    _setIsTyping(false);
    _typingTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipientName = widget.recipientProfile['username'] as String;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.blueGrey.shade700,
            backgroundImage: widget.recipientProfile['avatar_url'] != null &&
                    widget.recipientProfile['avatar_url'].isNotEmpty
                ? NetworkImage(widget.recipientProfile['avatar_url'])
                : null,
            child: (widget.recipientProfile['avatar_url'] == null ||
                    widget.recipientProfile['avatar_url'].isEmpty)
                ? const Icon(Icons.person, size: 20, color: Colors.white70)
                : null,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recipientName,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            // StreamBuilder para exibir o status em tempo real
            StreamBuilder<Map<String, dynamic>>(
              stream: _recipientStatusStream,
              initialData: {
                // Pega o status inicial do perfil para o primeiro estado
                'is_online': widget.recipientProfile['is_online'] ?? false,
                'is_typing': widget.isRecipientTyping
              },
              builder: (context, snapshot) {
                // Se o dado do stream for nulo, usa os dados iniciais
                final data = snapshot.data ?? {};

                // Os campos agora são acessados diretamente do mapa retornado pelo stream
                final bool isOnline = data['is_online'] == true;
                final bool isTyping = data['is_typing'] == true;

                String statusText;
                Color statusColor;

                // Lógica de prioridade de status: Digitanto > Online > Offline
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
      ),

      body: const Center(
        child: Text("Área de mensagens (Implementar Chat Bubble)",
            style: TextStyle(color: Colors.white70)),
      ),

      // Campo de texto com a lógica de digitação (debounce)
      bottomNavigationBar: Padding(
        // Adiciona um padding para considerar o teclado na navegação
        padding: EdgeInsets.only(
          left: 8.0,
          right: 8.0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8.0,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _messageController,
                onChanged: _handleTyping, // Chama a função de debounce
                decoration: InputDecoration(
                  hintText: 'Digite uma mensagem...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
