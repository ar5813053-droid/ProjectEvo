import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'ui/chat/chat_screen.dart';
import 'ui/home/home_shell.dart';
import 'ui/memory/memory_screen.dart';
import 'ui/research/research_screen.dart';
import 'ui/settings/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/chat',
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(path: '/chat', builder: (_, __) => const ChatScreen()),
        GoRoute(path: '/memory', builder: (_, __) => const MemoryScreen()),
        GoRoute(path: '/research', builder: (_, __) => const ResearchScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      ],
    ),
  ],
);

class ProjectEvoApp extends ConsumerWidget {
  const ProjectEvoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(inferenceReadyProvider);
    return MaterialApp.router(
      title: 'ProjectEVO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B4D3E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DDC97),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
