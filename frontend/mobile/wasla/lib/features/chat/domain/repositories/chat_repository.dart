abstract class ChatRepository {
  /// جلب كافة المحادثات الجارية للمستخدم الحالي (بائع أو مشتري)
  Future<List<Map<String, dynamic>>> getConversations();

  /// جلب رسائل محادثة معينة مرتبة زمنياً
  Future<List<Map<String, dynamic>>> getMessages(String conversationId);

  /// إرسال رسالة جديدة داخل محادثة
  Future<void> sendMessage(String conversationId, String content);

  /// إنشاء محادثة جديدة بين المشتري والبائع لإعلان معين
  Future<String> createConversation(String adId, String sellerId);

  /// بث حي للرسائل الجديدة داخل محادثة معينة في الوقت الفعلي
  Stream<List<Map<String, dynamic>>> streamMessages(String conversationId);
}
