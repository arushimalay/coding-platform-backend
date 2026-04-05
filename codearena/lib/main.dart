import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_theme.dart';
import 'auth_provider.dart';
import 'router.dart';

void main() {
  runApp(const CodingPlatformApp());
}

class CodingPlatformApp extends StatelessWidget {
  const CodingPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: Builder(
        builder: (context) {
          final router = buildRouter();
          return MaterialApp.router(
            title: 'CodeArena',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            routerConfig: router,
          );
        },
      ),
    );
  }
}