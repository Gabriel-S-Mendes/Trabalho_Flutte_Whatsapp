import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // Mapa para armazenar ID do usuário -> Nome de exibição (name_account)
  final Map<String, String> _usernames = {};
  final Map<String, List<String>> _reactions = {};
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;

  // Limite de arquivo: 20 MB
  static const int maxFileBytes = 20 * 1024 * 1024;

  @override
  void initState() {
    super.initState();

    _messagesStream = supabase
        .from('group_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', widget.groupId)
        .order('created_at', ascending: true);

    _loadUsernames();
    _listenReactions();
  }

  // ----------------------------
  // Reactions stream
  // ----------------------------
  void _listenReactions() {
    supabase
        .from('group_reactions')
        .stream(primaryKey: ['id'])
        .listen((event) {
      _syncReactions();
    });

    _syncReactions();
  }

  Future<void> _syncReactions() async {
    final resp = await supabase.from('group_reactions').select();

    final Map<String, List<String>> newMap = {};

    for (final r in resp) {
      final messageId = r['message_id']?.toString();
      final emoji = r['emoji'];
      if (messageId == null) continue;

      newMap.putIfAbsent(messageId, () => []);
      newMap[messageId]!.add(emoji);
    }

    if (mounted) {
      setState(() {
        _reactions
          ..clear()
          ..addAll(newMap);
      });
    }
  }

  // ----------------------------
  // Load usernames (display name)
  // ----------------------------
  Future<void> _loadUsernames() async {
    final profiles = await supabase.from('profiles').select('id, name_account, username');

    for (final p in profiles) {
      final String displayName = p['name_account'] ?? p['username'] ?? 'Desconhecido';
      _usernames[p['id']] = displayName;
    }

    if (mounted) setState(() {});
  }

  // ----------------------------
  // Send message (text / image / file)
  // ----------------------------
  Future<void> _sendMessage({String? content, String? imageUrl, String? fileUrl, String? fileName}) async {
    final text = content?.trim() ?? _messageController.text.trim();
    if ((text.isEmpty && imageUrl == null && fileUrl == null)) return;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    _messageController.clear();

    try {
      await supabase.from('group_messages').insert({
        'group_id': widget.groupId,
        'sender_id': userId,
        'content': text.isEmpty ? null : text,
        'image_url': imageUrl,
        'file_url': fileUrl,
        'file_name': fileName,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao enviar mensagem: $e')));
      }
    }
  }

  // ----------------------------
  // Send image (existing)
  // ----------------------------
  Future<void> _pickAndSendImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (picked == null) return;

    final Uint8List fileBytes = await picked.readAsBytes();
    final String fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    setState(() => _isSending = true);

    try {
      await supabase.storage.from('chat-images').uploadBinary(
            fileName,
            fileBytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: false),
          );

      final String imageUrl =
          supabase.storage.from('chat-images').getPublicUrl(fileName);

      await _sendMessage(imageUrl: imageUrl);
    } catch (e) {
      if (mounted) _showSnackBar("Erro ao enviar imagem: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ----------------------------
  // Send general file (up to 20MB) to bucket 'cha-files'
  // ----------------------------
  Future<void> _pickAndSendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        withReadStream: false,
        withData: true, // we want bytes
      );

      if (result == null) return; // usuario cancelou

      final PlatformFile file = result.files.first;

      final int size = file.size;
      if (size > maxFileBytes) {
        _showSnackBar("Arquivo maior que 20MB. Escolha um arquivo menor.");
        return;
      }

      final String originalName = file.name;
      final String ext = originalName.contains('.') ? originalName.split('.').last : '';
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${supabase.auth.currentUser?.id ?? 'anon'}${ext.isNotEmpty ? '.${ext}' : ''}";

      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        _showSnackBar("Não foi possível ler o arquivo selecionado.");
        return;
      }

      setState(() => _isSending = true);

      // Upload para cha-files
      await supabase.storage.from('cha-files').uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: _mimeFromExtension(ext),
              upsert: false,
            ),
          );

      final String fileUrl = supabase.storage.from('cha-files').getPublicUrl(fileName);

      // Salvar mensagem com file_url + file_name
      await _sendMessage(fileUrl: fileUrl, fileName: originalName);
    } catch (e) {
      _showSnackBar("Erro ao enviar arquivo: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // Pequena heurística de MIME
  String? _mimeFromExtension(String ext) {
    final e = ext.toLowerCase();
    if (e == 'png') return 'image/png';
    if (e == 'jpg' || e == 'jpeg') return 'image/jpeg';
    if (e == 'gif') return 'image/gif';
    if (e == 'mp4') return 'video/mp4';
    if (e == 'mov') return 'video/quicktime';
    if (e == 'pdf') return 'application/pdf';
    if (e == 'zip') return 'application/zip';
    if (e == 'docx') return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (e == 'doc') return 'application/msword';
    if (e == 'xlsx') return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (e == 'mp3') return 'audio/mpeg';
    return null;
  }

  // ----------------------------
  // Reactions (one per user)
  // ----------------------------
  void _addReaction(String messageId, String emoji) async {
    final userId = supabase.auth.currentUser!.id;

    try {
      await supabase
          .from('group_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);

      await supabase.from('group_reactions').insert({
        'message_id': messageId,
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

  // ----------------------------
  // Show members (com botão sair incluso)
  // ----------------------------
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
            .select('name_account, username')
            .eq('id', userId)
            .maybeSingle();

        final String displayName =
            profile?['name_account'] as String? ?? profile?['username'] as String? ?? 'Desconhecido';

        detailed.add({
          'user_id': userId,
          'display_name': displayName,
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
              itemCount: detailed.length + 1, // +1 = botão sair
              itemBuilder: (_, i) {
                if (i == detailed.length) {
                  // Botão sair do grupo
                  return ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text(
                      "Sair do grupo",
                      style: TextStyle(color: Colors.red),
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
                        Navigator.pop(context); // fecha grupo

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Você saiu do grupo.")),
                          );
                        }
                      } catch (e) {
                        if (mounted) _showSnackBar("Erro ao sair do grupo: $e");
                      }
                    },
                  );
                }

                final m = detailed[i];
                final String name = m['display_name'] as String;
                final String firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';

                return ListTile(
                  leading: CircleAvatar(child: Text(firstLetter)),
                  title: Text(name),
                  subtitle: Text(m['user_id']),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Fechar"),
            )
          ],
        ),
      );
    } catch (e) {
      _showSnackBar("Erro ao carregar membros: $e");
    }
  }

  // ----------------------------
  // UI helpers
  // ----------------------------
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      _showSnackBar("Não foi possível abrir o arquivo.");
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ----------------------------
  // Build
  // ----------------------------
  @override
  Widget build(BuildContext context) {
    final myId = supabase.auth.currentUser?.id ?? '';

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
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[messages.length - 1 - index];
                    final isMe = msg['sender_id'] == myId;

                    final username =
                        _usernames[msg['sender_id']] ?? 'Carregando...';
                    final messageId = msg['id'].toString();

                    return GestureDetector(
                      onTap: () => _showReactionsDialog(messageId),
                      child: _GroupBubble(
                        message: msg['content'],
                        imageUrl: msg['image_url'],
                        fileUrl: msg['file_url'],
                        fileName: msg['file_name'],
                        username: username,
                        isMe: isMe,
                        reactions: _reactions[messageId] ?? [],
                        onFileTap: (url) => _openUrl(url),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Campo de texto + botões
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: const Border(top: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                // Imagem
                IconButton(
                  icon: Icon(Icons.image,
                      color: _isSending ? Colors.grey : Colors.green),
                  onPressed: _isSending ? null : _pickAndSendImage,
                ),

                // Arquivo geral (clip)
                IconButton(
                  icon: Icon(Icons.attach_file,
                      color: _isSending ? Colors.grey : Colors.blueGrey),
                  onPressed: _isSending ? null : _pickAndSendFile,
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
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _isSending ? null : () => _sendMessage(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------
// Group bubble with file support
// ----------------------------
class _GroupBubble extends StatelessWidget {
  final String? message;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;
  final String username;
  final bool isMe;
  final List<String> reactions;
  final void Function(String) onFileTap;

  const _GroupBubble({
    this.message,
    this.imageUrl,
    this.fileUrl,
    this.fileName,
    required this.username,
    required this.isMe,
    required this.reactions,
    required this.onFileTap,
  });

  Widget _buildFileRow(BuildContext context) {
    if (fileUrl == null || fileName == null) return const SizedBox.shrink();

    final ext = fileName!.contains('.') ? fileName!.split('.').last.toLowerCase() : '';
    IconData icon;
    if (['png', 'jpg', 'jpeg', 'gif'].contains(ext)) {
      icon = Icons.image;
    } else if (['mp4', 'mov', 'webm'].contains(ext)) {
      icon = Icons.videocam;
    } else if (['mp3', 'wav'].contains(ext)) {
      icon = Icons.audiotrack;
    } else if (['pdf'].contains(ext)) {
      icon = Icons.picture_as_pdf;
    } else if (['zip', 'rar', '7z'].contains(ext)) {
      icon = Icons.archive;
    } else if (['doc', 'docx'].contains(ext)) {
      icon = Icons.article;
    } else {
      icon = Icons.insert_drive_file;
    }

    return GestureDetector(
      onTap: () {
        if (fileUrl != null) onFileTap(fileUrl!);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isMe ? Colors.green[300] : Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: isMe ? Colors.white : Colors.black87),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName ?? 'Arquivo',
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.download_rounded, size: 18, color: isMe ? Colors.white70 : Colors.black54),
          ],
        ),
      ),
    );
  }

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

            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!, style: const TextStyle(fontSize: 15)),
            ],

            // file (se existir)
            if (fileUrl != null && fileName != null) ...[
              const SizedBox(height: 6),
              _buildFileRow(context),
            ],

            if (imageUrl != null) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl!),
              ),
            ],

            if (reactions.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                children: reactions
                    .map((e) => Text(e, style: const TextStyle(fontSize: 16)))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
