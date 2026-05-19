import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:brainduel/core/theme/app_theme.dart';
import 'package:brainduel/core/routing/app_router.dart';
import 'package:brainduel/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase not yet configured — fill in firebase_options.dart with your project values
    // ignore: avoid_print
    print('[BrainDuel] Firebase init skipped: $e');
  }

  runApp(
    const ProviderScope(
      child: BrainDuelApp(),
    ),
  );
}

class BrainDuelApp extends ConsumerWidget {
  const BrainDuelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'BrainDuel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        // Wrap with a dark background to prevent white flash on navigation
        return Container(
          color: AppColors.backgroundStart,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
