import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';

void main() => runApp(const ChunoApp());

class ChunoApp extends StatelessWidget {
  const ChunoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '추노',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const LoginScreen(),
    );
  }
}
