import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:brainduel/features/auth/models/user_model.dart';
import 'package:brainduel/shared/services/firestore_service.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final String? idToken;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.idToken,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    String? idToken,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      idToken: idToken ?? this.idToken,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirestoreService _firestoreService;

  AuthNotifier({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required FirestoreService firestoreService,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _firestoreService = firestoreService,
        super(const AuthState(isLoading: true)) {
    checkAuthState();
  }

  Future<void> checkAuthState() async {
    state = state.copyWith(isLoading: true);
    try {
      final currentUser = _firebaseAuth.currentUser;
      if (currentUser != null) {
        final token = await currentUser.getIdToken();
        final userModel = UserModel(
          uid: currentUser.uid,
          displayName: currentUser.displayName ?? 'Player',
          email: currentUser.email ?? '',
          photoUrl: currentUser.photoURL,
        );
        state = state.copyWith(
          user: userModel,
          idToken: token,
          isLoading: false,
        );
      } else {
        state = state.copyWith(isLoading: false, clearUser: true);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        clearUser: true,
      );
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        state = state.copyWith(isLoading: false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);
      await _postSignIn(userCredential);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      UserCredential userCredential;
      try {
        userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found') {
          userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }
      await _postSignIn(userCredential);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _postSignIn(UserCredential credential,
      {String? overrideDisplayName}) async {
    final fbUser = credential.user;
    if (fbUser == null) {
      state = state.copyWith(isLoading: false, error: 'Sign in failed');
      return;
    }

    final displayName = overrideDisplayName ??
        fbUser.displayName ??
        fbUser.email?.split('@').first ??
        'Player';

    final token = await fbUser.getIdToken();

    // Create Firestore profile if new user
    if (credential.additionalUserInfo?.isNewUser == true) {
      await _firestoreService.createProfile(
        fbUser.uid,
        displayName,
        fbUser.email ?? '',
      );
    }

    final userModel = UserModel(
      uid: fbUser.uid,
      displayName: displayName,
      email: fbUser.email ?? '',
      photoUrl: fbUser.photoURL,
    );

    state = state.copyWith(
      user: userModel,
      idToken: token,
      isLoading: false,
    );
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
      state = AuthState(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String?> getIdToken() async {
    try {
      return await _firebaseAuth.currentUser?.getIdToken();
    } catch (_) {
      return null;
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    firebaseAuth: FirebaseAuth.instance,
    googleSignIn: GoogleSignIn(),
    firestoreService: FirestoreService(),
  );
});
