import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Folder Existence', () {
    test('lib/models folder exists', () {
      final dir = Directory('lib/models');
      expect(dir.existsSync(), true);
    });

    test('lib/screens folder exists', () {
      final dir = Directory('lib/screens');
      expect(dir.existsSync(), true);
    });

    test('lib/widgets folder exists', () {
      final dir = Directory('lib/widgets');
      expect(dir.existsSync(), true);
    });

    test('lib/services folder exists', () {
      final dir = Directory('lib/services');
      expect(dir.existsSync(), true);
    });

    test('lib/utils folder exists', () {
      final dir = Directory('lib/utils');
      expect(dir.existsSync(), true);
    });
  });
}