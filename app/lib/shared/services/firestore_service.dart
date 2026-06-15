import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._internal();
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  /// Returns the raw profile data map, or null if not found.
  Future<Map<String, dynamic>?> getProfileData(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return doc.data()!;
    } catch (e) {
      // ignore: avoid_print
      print('[FirestoreService] getProfileData error: $e');
      return null;
    }
  }

  Future<void> createProfile(
      String uid, String displayName, String email) async {
    try {
      await _users.doc(uid).set({
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'level': 1,
        'xp': 0,
        'coins': 100,
        'avatarId': 'default',
        'selectedAbilities': ['fiftyFifty', 'timeBoost'],
        'stats': {
          'wins': 0,
          'losses': 0,
          'draws': 0,
          'totalGames': 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('[FirestoreService] createProfile error: $e');
    }
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    try {
      await _users.doc(uid).update(data);
    } catch (e) {
      // ignore: avoid_print
      print('[FirestoreService] updateProfile error: $e');
    }
  }

  Future<void> addXpAndCoins(String uid, int xp, int coins) async {
    try {
      final doc = await _users.doc(uid).get();
      if (!doc.exists) return;
      final data = doc.data()!;
      final currentXp = (data['xp'] as int? ?? 0) + xp;
      final currentCoins = (data['coins'] as int? ?? 0) + coins;
      final newLevel = calculateLevel(currentXp);

      await _users.doc(uid).update({
        'xp': currentXp,
        'coins': currentCoins,
        'level': newLevel,
      });
    } catch (e) {
      // ignore: avoid_print
      print('[FirestoreService] addXpAndCoins error: $e');
    }
  }

  Future<void> incrementGameStats(String uid,
      {required bool isWin, required bool isDraw}) async {
    try {
      await _users.doc(uid).update({
        'totalGames': FieldValue.increment(1),
        if (isWin) 'wins': FieldValue.increment(1),
        if (!isWin && !isDraw) 'losses': FieldValue.increment(1),
        if (isDraw) 'draws': FieldValue.increment(1),
      });
    } catch (e) {
      // ignore: avoid_print
      print('[FirestoreService] incrementGameStats error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 50}) async {
    try {
      final snapshot = await _users
          .orderBy('wins', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[FirestoreService] getLeaderboard error: $e');
      return _mockLeaderboard();
    }
  }

  List<Map<String, dynamic>> _mockLeaderboard() {
    return List.generate(
      10,
      (i) => {
        'uid': 'mock_$i',
        'displayName': 'Player ${i + 1}',
        'level': 10 - i,
        'wins': 50 - i * 4,
        'avatarId': 'default',
      },
    );
  }

  static int xpToNextLevel(int currentLevel) => currentLevel * 500;

  static int calculateLevel(int totalXp) {
    int level = 1;
    int accumulated = 0;
    while (accumulated + level * 500 <= totalXp) {
      accumulated += level * 500;
      level++;
    }
    return level;
  }
}
