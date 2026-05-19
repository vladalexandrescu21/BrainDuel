import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:brainduel/features/auth/providers/auth_provider.dart';
import 'package:brainduel/features/auth/screens/login_screen.dart';
import 'package:brainduel/features/home/screens/home_screen.dart';
import 'package:brainduel/features/game/screens/matchmaking_screen.dart';
import 'package:brainduel/features/game/screens/game_screen.dart';
import 'package:brainduel/features/game/screens/result_screen.dart';
import 'package:brainduel/features/profile/screens/profile_screen.dart';
import 'package:brainduel/features/shop/screens/shop_screen.dart';
import 'package:brainduel/features/leaderboard/screens/leaderboard_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final isLoggedIn = authState.user != null;
      final isLoading = authState.isLoading;

      if (isLoading) return null;

      if (!isLoggedIn && state.matchedLocation != '/login') {
        return '/login';
      }

      if (isLoggedIn && state.matchedLocation == '/login') {
        return '/home';
      }

      if (state.matchedLocation == '/') {
        return isLoggedIn ? '/home' : '/login';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeTabContent(),
          ),
          GoRoute(
            path: '/leaderboard',
            builder: (context, state) => const LeaderboardScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/shop',
            builder: (context, state) => const ShopScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/matchmaking/:topicId',
        builder: (context, state) {
          final topicId = state.pathParameters['topicId'] ?? 'general_knowledge';
          return MatchmakingScreen(topicId: topicId);
        },
      ),
      GoRoute(
        path: '/game',
        builder: (context, state) => const GameScreen(),
      ),
      GoRoute(
        path: '/result',
        builder: (context, state) => const ResultScreen(),
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF7C3AED),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final Exception? error;

  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Error: ${error?.toString() ?? 'Unknown error'}'),
      ),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  final Widget child;

  const HomeShell({required this.child, super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _selectedIndex = 0;

  static const List<String> _routes = [
    '/home',
    '/leaderboard',
    '/profile',
    '/shop',
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    context.go(_routes[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2E),
          border: Border(
            top: BorderSide(color: Color(0x1AFFFFFF), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: const Color(0xFF1E1E2E),
          selectedItemColor: const Color(0xFF7C3AED),
          unselectedItemColor: const Color(0xFF94A3B8),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events), label: 'Leaderboard'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag), label: 'Shop'),
          ],
        ),
      ),
    );
  }
}
