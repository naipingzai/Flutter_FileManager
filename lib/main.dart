import 'package:flutter/material.dart';
import 'screens/file_manager_page.dart';

void main() {
  runApp(const AdvanceFileManagerApp());
}

class AdvanceFileManagerApp extends StatelessWidget {
  const AdvanceFileManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advance File Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const FileManagerPage(),
    );
  }
}
