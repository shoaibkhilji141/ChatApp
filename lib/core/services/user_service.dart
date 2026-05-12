import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<AppUser>> streamAllUsersExcept(String currentUid) {
    return _firestore
        .collection('users')
        .orderBy('usernameLower')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromMap(doc.data()))
              .where((user) => user.uid.isNotEmpty && user.uid != currentUid)
              .toList(),
        );
  }

  Stream<AppUser?> streamUserByUid(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return null;
      }
      return AppUser.fromMap(doc.data() ?? <String, dynamic>{});
    });
  }

  Future<void> updateProfileImage({
    required String uid,
    required String profileImageBase64,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'profileImageBase64': profileImageBase64,
    }, SetOptions(merge: true));
  }

  Future<void> updateUsername({
    required String uid,
    required String username,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty) {
      throw Exception('Username cannot be empty.');
    }

    final existingUsername = await _firestore
        .collection('users')
        .where('usernameLower', isEqualTo: normalizedUsername.toLowerCase())
        .limit(1)
        .get();

    final isTaken = existingUsername.docs.any((doc) => doc.id != uid);
    if (isTaken) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'Username is already taken.',
      );
    }

    await _firestore.collection('users').doc(uid).set({
      'username': normalizedUsername,
      'usernameLower': normalizedUsername.toLowerCase(),
    }, SetOptions(merge: true));
  }

  Future<void> updateDescription({
    required String uid,
    required String description,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'description': description.trim(),
    }, SetOptions(merge: true));
  }
}
