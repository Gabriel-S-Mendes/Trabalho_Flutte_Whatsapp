// chat_item_model.dart

class ChatItem {
  final String id;
  final String title;
  final String? avatarUrl;
  final bool isGroup;
  final Map<String, dynamic> data;

  ChatItem({
    required this.id,
    required this.title,
    this.avatarUrl,
    required this.isGroup,
    required this.data,
  });
}
