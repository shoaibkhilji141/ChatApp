import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/message_crypto.dart';

class ConversationSummary {
  const ConversationSummary({
    required this.roomId,
    required this.participants,
    required this.isGroup,
    required this.groupName,
    required this.lastMessageText,
    required this.lastMessageSenderId,
    required this.lastMessageReceiverId,
    required this.lastMessageAt,
    required this.lastMessageDelivered,
    required this.lastMessageRead,
    required this.unreadBy,
  });

  final String roomId;
  final List<String> participants;
  final bool isGroup;
  final String groupName;
  final String lastMessageText;
  final String lastMessageSenderId;
  final String lastMessageReceiverId;
  final DateTime? lastMessageAt;
  final bool lastMessageDelivered;
  final bool lastMessageRead;
  final Map<String, int> unreadBy;

  int unreadFor(String uid) => unreadBy[uid] ?? 0;

  String? otherParticipant(String currentUid) {
    for (final uid in participants) {
      if (uid != currentUid) {
        return uid;
      }
    }
    return null;
  }

  factory ConversationSummary.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    final participantsRaw =
        (data['participants'] as List<dynamic>? ?? const []);
    final participants = participantsRaw
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .toList();

    final unreadRaw = (data['unreadBy'] as Map<String, dynamic>? ?? const {});
    final unreadBy = <String, int>{};
    unreadRaw.forEach((key, value) {
      unreadBy[key] = (value as num?)?.toInt() ?? 0;
    });

    return ConversationSummary(
      roomId: doc.id,
      participants: participants,
      isGroup: (data['isGroup'] ?? false) as bool,
      groupName: (data['groupName'] ?? '') as String,
      lastMessageText: MessageCrypto.decryptString(
        (data['lastMessageText'] ?? '') as String,
      ),
      lastMessageSenderId: (data['lastMessageSenderId'] ?? '') as String,
      lastMessageReceiverId: (data['lastMessageReceiverId'] ?? '') as String,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageDelivered: (data['lastMessageDelivered'] ?? false) as bool,
      lastMessageRead: (data['lastMessageRead'] ?? false) as bool,
      unreadBy: unreadBy,
    );
  }
}
