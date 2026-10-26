import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_models.freezed.dart';
part 'chat_models.g.dart';

@freezed
class ChatMessage with _$ChatMessage {
  const factory ChatMessage({
    required String id,
    required String conversationId,
    required String senderId,
    required String content,
    required bool isRead,
    required DateTime createdAt,
  }) = _ChatMessage;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
}

@freezed
class Conversation with _$Conversation {
  const factory Conversation({
    required String id,
    required String adId,
    required String buyerId,
    required String sellerId,
    required DateTime lastMessageAt,
    String? lastMessagePreview,
    required DateTime createdAt,
    // Joined data
    String? adTitle,
    String? otherUserFullName,
    String? otherUserAvatarUrl,
  }) = _Conversation;

  factory Conversation.fromJson(Map<String, dynamic> json) => _$ConversationFromJson(json);
}
