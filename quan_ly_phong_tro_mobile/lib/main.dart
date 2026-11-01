import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'screens/login_screen.dart';

void main() {
  runApp(const QuanLyPhongTroApp());
}

class QuanLyPhongTroApp extends StatefulWidget {
  const QuanLyPhongTroApp({super.key});

  @override
  State<QuanLyPhongTroApp> createState() => _QuanLyPhongTroAppState();
}

class _QuanLyPhongTroAppState extends State<QuanLyPhongTroApp> {
  final ApiClient api = ApiClient();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quản lý phòng trọ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
      ),
      home: LoginScreen(api: api),
    );
  }
}
