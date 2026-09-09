import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ui/app_state.dart';
import 'ui/screens/home_screen.dart';
import 'ui/theme/app_theme.dart';

class EmojiPackApp extends StatelessWidget {
  const EmojiPackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: '表情包管理',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const HomeScreen(),
      ),
    );
  }
}
