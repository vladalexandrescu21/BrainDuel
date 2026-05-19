class UserModel {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final String avatarId;

  const UserModel({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    this.avatarId = 'default',
  });

  UserModel copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? photoUrl,
    String? avatarId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      avatarId: avatarId ?? this.avatarId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'avatarId': avatarId,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      displayName: map['displayName'] as String? ?? 'Player',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      avatarId: map['avatarId'] as String? ?? 'default',
    );
  }
}
