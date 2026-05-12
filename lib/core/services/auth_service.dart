import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentAuthUser => _auth.currentUser;

  Future<bool> isEmailRegistered(String email) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      return false;
    }

    final result = await _firestore
        .collection('users')
        .where('email', isEqualTo: normalizedEmail)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  Future<void> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedEmail = email.trim().toLowerCase();

    final existingUsername = await _firestore
        .collection('users')
        .where('usernameLower', isEqualTo: normalizedUsername.toLowerCase())
        .limit(1)
        .get();

    if (existingUsername.docs.isNotEmpty) {
      throw FirebaseAuthException(
        code: 'username-already-in-use',
        message: 'Username is already taken.',
      );
    }

    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final uid = credential.user?.uid;
    if (uid == null) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Unable to create user account.',
      );
    }

    final appUser = AppUser(
      uid: uid,
      username: normalizedUsername,
      email: normalizedEmail,
      profileImageBase64: '',
      description: '',
    );

    await _firestore.collection('users').doc(uid).set({
      ...appUser.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> signIn({
    required String usernameOrEmail,
    required String password,
  }) async {
    final input = usernameOrEmail.trim();
    var emailToLogin = input;

    if (!input.contains('@')) {
      final result = await _firestore
          .collection('users')
          .where('usernameLower', isEqualTo: input.toLowerCase())
          .limit(1)
          .get();

      if (result.docs.isEmpty) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'No account found for that username.',
        );
      }

      emailToLogin = (result.docs.first.data()['email'] ?? '') as String;
    }

    await _auth.signInWithEmailAndPassword(
      email: emailToLogin,
      password: password,
    );
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = _auth.currentUser;
    final currentEmail = currentUser?.email;

    if (currentUser == null || currentEmail == null || currentEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-user',
        message: 'Please sign in again and try.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: currentEmail,
      password: currentPassword,
    );

    await currentUser.reauthenticateWithCredential(credential);
    await currentUser.updatePassword(newPassword);
  }
}
