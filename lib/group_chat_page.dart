import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  // ----------------------------------------------------
  // 🔥 Impede usuário de acessar o grupo após sair
  // ----------------------------------------------------
  Future<void> _checkMembership() async {
    final userId = supabase.auth.currentUser!.id;

    final res = await supabase
        .from('group_members')
        .select()
        .eq('group_id', widget.groupId)
        .eq('user_id', userId)
        .maybeSingle();

    if (!mounted) return;

    if (res == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Você não faz mais parte desse grupo.")),
      );
    }
  }

  // ----------------------------------------------------
  // 🔥 Popup que lista membros + botão de sair do grupo
  // ----------------------------------------------------
  Future<void> _showMembers() async {
    try {
      final members = await supabase
          .from('group_members')
          .select('user_id')
          .eq('group_id', widget.groupId);

      final List memList = members as List? ?? [];

      List<Map<String, dynamic>> detailed = [];

      for (final m in memList) {
        final userId = m['user_id'];

        final profile = await supabase
            .from('profiles')
            .select('username')
            .eq('id', userId)
            .maybeSingle();

        detailed.add({
          'user_id': userId,
          'username': profile?['username'] ?? 'Desconhecido',
        });
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Integrantes do grupo"),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: ListView.builder(
              itemCount: detailed.length + 1, // +1 para o botão de sair
              itemBuilder: (_, i) {
                // -----------------------------------------------
                // 🔥 Botão "SAIR DO GRUPO" dentro da lista
                // -----------------------------------------------
                if (i == detailed.length) {
                  return ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      "Sair do grupo",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () async {
                      final userId = supabase.auth.currentUser!.id;

                      try {
                        await supabase
                            .from('group_members')
                            .delete()
                            .eq('group_id', widget.groupId)
                            .eq('user_id', userId);

                        Navigator.pop(ctx); // fecha popup
                        Navigator.pop(context); // sai da tela do grupo

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Você saiu do grupo.")),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content:
                                  Text("Erro ao sair do grupo: $e")),
                        );
                      }
                    },
                  );
                }

                // -----------------------------------------------
                // 🔥 Exibir membros normalmente
                // -----------------------------------------------
                final m = detailed[i];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      m['username'][0].toUpperCase(),
                    ),
                  ),
                  title: Text(m['username']),
                  subtitle: Text(m['user_id']),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Fechar"),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao carregar participantes: $e")),
      );
    }
  }

  // ----------------------------------------------------
  // 🔥 Enviar mensagem
  // ----------------------------------------------------
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userId = supabase.auth.currentUser!.id;

    await supabase.from('messages').insert({
      'group_id': widget.groupId,
      'sender_id': userId,
      'content': text,
    });

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: _showMembers,
          ),
        ],
      ),

      // ----------------------------------------------------
      // 🔥 Stream de mensagens em tempo real
      // ----------------------------------------------------
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('group_id', widget.groupId)
                  .order('created_at')
                  .map((rows) => rows),
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (_, i) {
                    final msg = messages[i];
                    final isMe =
                        msg['sender_id'] == supabase.auth.currentUser!.id;

                    return Container(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.blue[300]
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(msg['content']),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ----------------------------------------------------
          // 🔥 Caixa de texto para enviar mensagem
          // ----------------------------------------------------
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration:
                        const InputDecoration(hintText: "Escreva algo..."),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
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
