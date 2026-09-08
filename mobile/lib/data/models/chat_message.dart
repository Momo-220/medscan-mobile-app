class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;
  final String? imageUrl; // Optional image attached to this message
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    this.imageUrl,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String? ?? 'user',
      content: json['content'] as String? ?? '',
      imageUrl: json['image_url'] as String?,
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp'] as String) 
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      if (imageUrl != null) 'image_url': imageUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
