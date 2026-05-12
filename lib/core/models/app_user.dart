class AppUser {
  const AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.profileImageBase64,
    this.description = '',
  });

  final String uid;
  final String username;
  final String email;
  final String profileImageBase64;
  final String description;

  bool get hasProfileImage => profileImageBase64.isNotEmpty;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: (map['uid'] ?? '') as String,
      username: (map['username'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      profileImageBase64: (map['profileImageBase64'] ?? '') as String,
      description: (map['description'] ?? '') as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'usernameLower': username.toLowerCase(),
      'email': email,
      'profileImageBase64': profileImageBase64,
      'description': description,
    };
  }
}
