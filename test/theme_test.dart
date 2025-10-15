import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcq_quizzer/main.dart';

void main() {
  group('ThemeProvider', () {
    test('initial theme mode is light', () {
      final themeProvider = ThemeProvider();
      expect(themeProvider.themeMode, ThemeMode.light);
    });

    test('toggle theme changes from light to dark', () {
      final themeProvider = ThemeProvider();
      themeProvider.toggleTheme();
      expect(themeProvider.themeMode, ThemeMode.dark);
    });

    test('toggle theme changes from dark to light', () {
      final themeProvider = ThemeProvider();
      themeProvider.toggleTheme(); // to dark
      themeProvider.toggleTheme(); // back to light
      expect(themeProvider.themeMode, ThemeMode.light);
    });
  });
}