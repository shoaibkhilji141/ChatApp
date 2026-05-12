import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/message_crypto.dart';

enum MessageReceiptStatus { sent, delivered, read }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.messageType,
    required this.imageUrl,
    required this.createdAt,
    required this.deliveredTo,
    required this.readBy,
  });

  final String id;
  final String senderId;
  final String text;
  final String messageType;
  final String imageUrl;
  final DateTime createdAt;
  final List<String> deliveredTo;
  final List<String> readBy;

  bool get isImage => messageType == 'image' && imageUrl.isNotEmpty;

  MessageReceiptStatus receiptStatusFor(String recipientUid) {
    if (readBy.contains(recipientUid)) {
      return MessageReceiptStatus.read;
    }
    if (deliveredTo.contains(recipientUid)) {
      return MessageReceiptStatus.delivered;
    }
    return MessageReceiptStatus.sent;
  }

  factory ChatMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final timestamp = data['createdAt'] as Timestamp?;
    final deliveredTo = (data['deliveredTo'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList();
    final readBy = (data['readBy'] as List<dynamic>? ?? const [])
        .map((value) => value.toString())
        .toList();

    return ChatMessage(
      id: doc.id,
      senderId: (data['senderId'] ?? '') as String,
      text: MessageCrypto.decryptString((data['text'] ?? '') as String),
      messageType: (data['messageType'] ?? 'text') as String,
      imageUrl: MessageCrypto.decryptString((data['imageUrl'] ?? '') as String),
      createdAt: timestamp?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      deliveredTo: deliveredTo,
      readBy: readBy,
    );
  }
}
