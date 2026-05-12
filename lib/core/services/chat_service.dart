import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

import '../models/chat_message.dart';
import '../models/conversation_summary.dart';
import 'message_crypto.dart';

class ChatService {
  ChatService._();

  static final ChatService instance = ChatService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String roomIdFor(String firstUid, String secondUid) {
    final sorted = [firstUid, secondUid]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  Future<String> createGroup({
    required String name,
    required List<String> memberUids,
    required String adminUid,
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc();
    final unreadBy = <String, int>{};
    for (final uid in memberUids) {
      unreadBy[uid] = 0;
    }

    await roomRef.set({
      'participants': memberUids,
      'isGroup': true,
      'groupName': name,
      'admins': [adminUid],
      'unreadBy': unreadBy,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return roomRef.id;
  }

  Stream<List<ChatMessage>> streamMessages({
    required String currentUid,
    required String otherUid,
  }) {
    final roomId = roomIdFor(currentUid, otherUid);

    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  Stream<List<ConversationSummary>> streamConversations(String currentUid) {
    return _firestore
        .collection('chatRooms')
        .where('participants', arrayContains: currentUid)
        .snapshots()
        .map((snapshot) {
          final summaries = snapshot.docs
              .map(ConversationSummary.fromDoc)
              .toList();

          summaries.sort((first, second) {
            final firstTime = first.lastMessageAt;
            final secondTime = second.lastMessageAt;
            if (firstTime == null && secondTime == null) {
              return 0;
            }
            if (firstTime == null) {
              return 1;
            }
            if (secondTime == null) {
              return -1;
            }
            return secondTime.compareTo(firstTime);
          });

          return summaries;
        });
  }

  Stream<List<ChatMessage>> streamGroupMessages(String roomId) {
    return _firestore
        .collection('chatRooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs.map(ChatMessage.fromDoc).toList());
  }

  Future<Map<String, dynamic>?> fetchRoomData(String roomId) async {
    final snapshot = await _firestore.collection('chatRooms').doc(roomId).get();
    return snapshot.data();
  }

  Future<void> removeGroupMember({
    required String roomId,
    required String memberUid,
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) {
        throw Exception('Group not found.');
      }

      final roomData = snapshot.data() ?? <String, dynamic>{};
      final participants =
          (roomData['participants'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty && value != memberUid)
              .toList();

      final admins = (roomData['admins'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList();

      final unreadRaw = (roomData['unreadBy'] as Map<String, dynamic>? ?? {});
      final unreadBy = <String, int>{};
      unreadRaw.forEach((key, value) {
        final uid = key.toString();
        if (uid == memberUid) {
          return;
        }
        unreadBy[uid] = (value as num?)?.toInt() ?? 0;
      });

      transaction.set(roomRef, {
        'participants': participants,
        'admins': admins,
        'unreadBy': unreadBy,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> addGroupMembers({
    required String roomId,
    required List<String> memberUids,
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomRef);
      if (!snapshot.exists) {
        throw Exception('Group not found.');
      }

      final roomData = snapshot.data() ?? <String, dynamic>{};
      final participants =
          (roomData['participants'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .where((value) => value.isNotEmpty)
              .toSet();
      final unreadRaw = (roomData['unreadBy'] as Map<String, dynamic>? ?? {});
      final unreadBy = <String, int>{};

      unreadRaw.forEach((key, value) {
        unreadBy[key.toString()] = (value as num?)?.toInt() ?? 0;
      });

      for (final memberUid in memberUids) {
        participants.add(memberUid);
        unreadBy[memberUid] = unreadBy[memberUid] ?? 0;
      }

      transaction.set(roomRef, {
        'participants': participants.toList(),
        'unreadBy': unreadBy,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> sendMessage({
    required String senderUid,
    required String receiverUid,
    required String text,
  }) async {
    final roomId = roomIdFor(senderUid, receiverUid);
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final roomData = roomSnapshot.data() ?? <String, dynamic>{};
      final unreadRaw = (roomData['unreadBy'] as Map<String, dynamic>? ?? {});
      final unreadBy = <String, int>{};

      unreadRaw.forEach((key, value) {
        unreadBy[key] = (value as num?)?.toInt() ?? 0;
      });

      unreadBy[receiverUid] = (unreadBy[receiverUid] ?? 0) + 1;
      unreadBy[senderUid] = 0;

      transaction.set(roomRef, {
        'participants': [senderUid, receiverUid],
        'lastMessageText': MessageCrypto.encryptString(text),
        'lastMessageSenderId': senderUid,
        'lastMessageReceiverId': receiverUid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageDelivered': false,
        'lastMessageRead': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadBy': unreadBy,
      }, SetOptions(merge: true));

      transaction.set(messageRef, {
        'senderId': senderUid,
        'text': MessageCrypto.encryptString(text),
        'messageType': 'text',
        'imageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'deliveredTo': [senderUid],
        'readBy': [senderUid],
      });
    });
  }

  Future<void> sendGroupMessage({
    required String senderUid,
    required String roomId,
    required String text,
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final roomData = roomSnapshot.data() ?? <String, dynamic>{};
      final participants =
          (roomData['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final unreadRaw = (roomData['unreadBy'] as Map<String, dynamic>? ?? {});
      final unreadBy = <String, int>{};
      unreadRaw.forEach((key, value) {
        unreadBy[key] = (value as num?)?.toInt() ?? 0;
      });

      for (final uid in participants) {
        if (uid == senderUid) {
          unreadBy[uid] = 0;
        } else {
          unreadBy[uid] = (unreadBy[uid] ?? 0) + 1;
        }
      }

      transaction.set(roomRef, {
        'lastMessageText': MessageCrypto.encryptString(text),
        'lastMessageSenderId': senderUid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageDelivered': false,
        'lastMessageRead': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadBy': unreadBy,
      }, SetOptions(merge: true));

      transaction.set(messageRef, {
        'senderId': senderUid,
        'text': MessageCrypto.encryptString(text),
        'messageType': 'text',
        'imageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
        'deliveredTo': [senderUid],
        'readBy': [senderUid],
      });
    });
  }

  Future<void> sendGroupImage({
    required String senderUid,
    required String roomId,
    required File imageFile,
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unable to process the captured image.');
    }

    final resized = decoded.width > 1024
        ? img.copyResize(decoded, width: 1024)
        : decoded;
    final compressedBytes = img.encodeJpg(resized, quality: 60);
    final imageBase64 = base64Encode(compressedBytes);

    if (compressedBytes.length > 800000) {
      throw Exception(
        'Captured image is still too large. Please retake a smaller photo.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final roomData = roomSnapshot.data() ?? <String, dynamic>{};
      final participants =
          (roomData['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      final unreadRaw = (roomData['unreadBy'] as Map<String, dynamic>? ?? {});
      final unreadBy = <String, int>{};
      unreadRaw.forEach((key, value) {
        unreadBy[key] = (value as num?)?.toInt() ?? 0;
      });

      for (final uid in participants) {
        if (uid == senderUid) {
          unreadBy[uid] = 0;
        } else {
          unreadBy[uid] = (unreadBy[uid] ?? 0) + 1;
        }
      }

      transaction.set(roomRef, {
        'lastMessageText': MessageCrypto.encryptString('📷 Photo'),
        'lastMessageSenderId': senderUid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageDelivered': false,
        'lastMessageRead': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadBy': unreadBy,
      }, SetOptions(merge: true));

      transaction.set(messageRef, {
        'senderId': senderUid,
        'text': '',
        'messageType': 'image',
        'imageUrl': MessageCrypto.encryptString(imageBase64),
        'createdAt': FieldValue.serverTimestamp(),
        'deliveredTo': [senderUid],
        'readBy': [senderUid],
      });
    });
  }

  Future<void> sendImageMessage({
    required String senderUid,
    required String receiverUid,
    required File imageFile,
  }) async {
    final roomId = roomIdFor(senderUid, receiverUid);
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unable to process the captured image.');
    }

    final resized = decoded.width > 1024
        ? img.copyResize(decoded, width: 1024)
        : decoded;
    final compressedBytes = img.encodeJpg(resized, quality: 60);
    final imageBase64 = base64Encode(compressedBytes);

    if (compressedBytes.length > 800000) {
      throw Exception(
        'Captured image is still too large. Please retake a smaller photo.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);
      final roomData = roomSnapshot.data() ?? <String, dynamic>{};
      final unreadRaw = (roomData['unreadBy'] as Map<String, dynamic>? ?? {});
      final unreadBy = <String, int>{};

      unreadRaw.forEach((key, value) {
        unreadBy[key] = (value as num?)?.toInt() ?? 0;
      });

      unreadBy[receiverUid] = (unreadBy[receiverUid] ?? 0) + 1;
      unreadBy[senderUid] = 0;

      transaction.set(roomRef, {
        'participants': [senderUid, receiverUid],
        'lastMessageText': MessageCrypto.encryptString('📷 Photo'),
        'lastMessageSenderId': senderUid,
        'lastMessageReceiverId': receiverUid,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageDelivered': false,
        'lastMessageRead': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'unreadBy': unreadBy,
      }, SetOptions(merge: true));

      transaction.set(messageRef, {
        'senderId': senderUid,
        'text': '',
        'messageType': 'image',
        'imageUrl': MessageCrypto.encryptString(imageBase64),
        'createdAt': FieldValue.serverTimestamp(),
        'deliveredTo': [senderUid],
        'readBy': [senderUid],
      });
    });
  }

  Future<void> markConversationAsRead({
    required String currentUid,
    required String otherUid,
  }) async {
    final roomId = roomIdFor(currentUid, otherUid);
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists) {
      return;
    }

    await roomRef.update({'unreadBy.$currentUid': 0});

    final roomData = roomSnapshot.data() ?? <String, dynamic>{};
    final shouldMarkLastRead =
        roomData['lastMessageSenderId'] == otherUid &&
        roomData['lastMessageReceiverId'] == currentUid;

    if (shouldMarkLastRead) {
      await roomRef.set({
        'lastMessageDelivered': true,
        'lastMessageRead': true,
      }, SetOptions(merge: true));
    }

    final incomingMessages = await roomRef
        .collection('messages')
        .where('senderId', isEqualTo: otherUid)
        .get();

    final batch = _firestore.batch();
    var hasUpdates = false;
    for (final doc in incomingMessages.docs) {
      final data = doc.data();
      final readBy = (data['readBy'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();
      final deliveredTo = (data['deliveredTo'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();

      if (readBy.contains(currentUid) && deliveredTo.contains(currentUid)) {
        continue;
      }

      batch.update(doc.reference, {
        'deliveredTo': FieldValue.arrayUnion([currentUid]),
        'readBy': FieldValue.arrayUnion([currentUid]),
      });
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  Future<void> markGroupConversationAsRead({
    required String currentUid,
    required String roomId,
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists) {
      return;
    }

    await roomRef.update({'unreadBy.$currentUid': 0});

    final incomingMessages = await roomRef
        .collection('messages')
        .where('readBy', arrayContains: currentUid)
        .get();

    final batch = _firestore.batch();
    var hasUpdates = false;
    for (final doc in incomingMessages.docs) {
      final data = doc.data();
      final readBy = (data['readBy'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();
      final deliveredTo = (data['deliveredTo'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();

      if (readBy.contains(currentUid) && deliveredTo.contains(currentUid)) {
        continue;
      }

      batch.update(doc.reference, {
        'deliveredTo': FieldValue.arrayUnion([currentUid]),
        'readBy': FieldValue.arrayUnion([currentUid]),
      });
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  Future<void> markGroupIncomingAsDelivered({
    required String currentUid,
    required String roomId,
  }) async {
    final roomRef = _firestore.collection('chatRooms').doc(roomId);
    final roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists) {
      return;
    }

    final pendingMessages = await roomRef
        .collection('messages')
        .where('senderId', isNotEqualTo: currentUid)
        .get();

    final batch = _firestore.batch();
    var hasUpdates = false;
    for (final doc in pendingMessages.docs) {
      final data = doc.data();
      final deliveredTo = (data['deliveredTo'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();

      if (deliveredTo.contains(currentUid)) {
        continue;
      }

      batch.update(doc.reference, {
        'deliveredTo': FieldValue.arrayUnion([currentUid]),
      });
      hasUpdates = true;
    }

    if (!hasUpdates) {
      return;
    }

    await batch.commit();
  }

  Future<void> markIncomingAsDelivered({
    required String currentUid,
    required String otherUid,
  }) async {
    final roomId = roomIdFor(currentUid, otherUid);
    final roomRef = _firestore.collection('chatRooms').doc(roomId);

    final roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists) {
      return;
    }

    final roomData = roomSnapshot.data() ?? <String, dynamic>{};
    final shouldMarkLastDelivered =
        roomData['lastMessageSenderId'] == otherUid &&
        roomData['lastMessageReceiverId'] == currentUid;
    if (shouldMarkLastDelivered) {
      await roomRef.set({
        'lastMessageDelivered': true,
      }, SetOptions(merge: true));
    }

    final pendingMessages = await roomRef
        .collection('messages')
        .where('senderId', isEqualTo: otherUid)
        .get();

    final batch = _firestore.batch();
    var hasUpdates = false;
    for (final doc in pendingMessages.docs) {
      final data = doc.data();
      final deliveredTo = (data['deliveredTo'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();

      if (deliveredTo.contains(currentUid)) {
        continue;
      }

      batch.update(doc.reference, {
        'deliveredTo': FieldValue.arrayUnion([currentUid]),
      });
      hasUpdates = true;
    }

    if (!hasUpdates) {
      return;
    }

    await batch.commit();
  }
}
