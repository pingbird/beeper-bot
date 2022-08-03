import 'package:admin2/pages/console.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme.copyWith(
        scaffoldBackgroundColor: const Color(0xff809c5f),
        primaryColor: const Color(0xff3c4043),
        colorScheme: theme.colorScheme.copyWith(
          secondary: const Color(0xff809c5f),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: MaterialStateProperty.all(const EdgeInsets.all(16)),
            backgroundColor: MaterialStateProperty.all(const Color(0xff809c5f)),
            textStyle: MaterialStateProperty.all(
              GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: ButtonStyle(
            padding: MaterialStateProperty.all(const EdgeInsets.all(16)),
            foregroundColor: MaterialStateProperty.all(Colors.white),
            overlayColor: MaterialStateProperty.all(
              Colors.white.withOpacity(0.05),
            ),
            textStyle: MaterialStateProperty.all(
              GoogleFonts.nunito(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
      home: const ConsolePage(),
    );
  }
}
