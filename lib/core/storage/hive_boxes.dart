import 'package:hive_flutter/hive_flutter.dart';

/// Box names. Every record is stored as a plain Map<dynamic, dynamic> —
/// deliberately avoiding generated TypeAdapters so the project builds with
/// nothing more than `flutter pub get` (no build_runner step required in CI).
class HiveBoxes {
  HiveBoxes._();

  static const String library = 'library_documents_v1';
  static const String trash = 'trash_items_v1';
  static const String history = 'tool_history_v1';
  static const String prefs = 'app_prefs_v1';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(library),
      Hive.openBox(trash),
      Hive.openBox(history),
      Hive.openBox(prefs),
    ]);
  }
}
