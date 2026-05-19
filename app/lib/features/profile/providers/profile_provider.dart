import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brainduel/features/auth/providers/auth_provider.dart';
import 'package:brainduel/shared/services/firestore_service.dart';

class ProfileState {
  final String? uid;
  final String displayName;
  final int level;
  final int xp;
  final int xpToNextLevel;
  final int coins;
  final String avatarId;
  final List<String> selectedAbilities; // 2 ability types
  final Map<String, int> stats; // wins, losses, draws, totalGames
  final bool isLoading;

  const ProfileState({
    this.uid,
    this.displayName = 'Player',
    this.level = 1,
    this.xp = 0,
    this.xpToNextLevel = 500,
    this.coins = 0,
    this.avatarId = 'default',
    this.selectedAbilities = const ['fiftyFifty', 'timeBoost'],
    this.stats = const {
      'wins': 0,
      'losses': 0,
      'draws': 0,
      'totalGames': 0,
    },
    this.isLoading = false,
  });

  ProfileState copyWith({
    String? uid,
    String? displayName,
    int? level,
    int? xp,
    int? xpToNextLevel,
    int? coins,
    String? avatarId,
    List<String>? selectedAbilities,
    Map<String, int>? stats,
    bool? isLoading,
  }) {
    return ProfileState(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      xpToNextLevel: xpToNextLevel ?? this.xpToNextLevel,
      coins: coins ?? this.coins,
      avatarId: avatarId ?? this.avatarId,
      selectedAbilities: selectedAbilities ?? this.selectedAbilities,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  double get xpProgress {
    if (xpToNextLevel <= 0) return 1.0;
    // xp within current level
    int accumulated = 0;
    int lvl = 1;
    int target = xp;
    while (accumulated + lvl * 500 <= target) {
      accumulated += lvl * 500;
      lvl++;
    }
    final xpInLevel = target - accumulated;
    return (xpInLevel / (lvl * 500)).clamp(0.0, 1.0);
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final FirestoreService _firestore;
  final Ref _ref;

  ProfileNotifier({
    required FirestoreService firestore,
    required Ref ref,
  })  : _firestore = firestore,
        _ref = ref,
        super(const ProfileState(isLoading: true)) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final authState = _ref.read(authProvider);
    if (authState.user == null) {
      state = const ProfileState(isLoading: false);
      return;
    }

    final uid = authState.user!.uid;
    state = state.copyWith(isLoading: true);

    try {
      final data = await _firestore.getProfileData(uid);
      if (data != null) {
        final level = data['level'] as int? ?? 1;
        state = ProfileState(
          uid: uid,
          displayName: data['displayName'] as String? ?? 'Player',
          level: level,
          xp: data['xp'] as int? ?? 0,
          xpToNextLevel: FirestoreService.xpToNextLevel(level),
          coins: data['coins'] as int? ?? 0,
          avatarId: data['avatarId'] as String? ?? 'default',
          selectedAbilities: List<String>.from(
            data['selectedAbilities'] as List? ?? ['fiftyFifty', 'timeBoost'],
          ),
          stats: {
            'wins': data['wins'] as int? ?? 0,
            'losses': data['losses'] as int? ?? 0,
            'draws': data['draws'] as int? ?? 0,
            'totalGames': data['totalGames'] as int? ?? 0,
          },
          isLoading: false,
        );
      } else {
        // Use auth display name as fallback
        state = ProfileState(
          uid: uid,
          displayName: authState.user!.displayName,
          isLoading: false,
        );
      }
    } catch (e) {
      state = ProfileState(
        uid: uid,
        displayName: authState.user?.displayName ?? 'Player',
        isLoading: false,
      );
    }
  }

  Future<void> refreshProfile() async {
    await _loadProfile();
  }

  Future<void> updateDisplayName(String name) async {
    if (state.uid == null) return;
    state = state.copyWith(displayName: name);
    await _firestore.updateProfile(state.uid!, {'displayName': name});
  }

  Future<void> updateSelectedAbilities(List<String> abilities) async {
    if (state.uid == null) return;
    state = state.copyWith(selectedAbilities: abilities);
    await _firestore.updateProfile(
        state.uid!, {'selectedAbilities': abilities});
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final notifier = ProfileNotifier(
    firestore: FirestoreService(),
    ref: ref,
  );
  // Re-load profile when auth state changes
  ref.listen(authProvider, (previous, next) {
    if (previous?.user?.uid != next.user?.uid) {
      notifier.refreshProfile();
    }
  });
  return notifier;
});
