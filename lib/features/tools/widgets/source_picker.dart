import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Picks input files for tools directly from device storage.
/// Tool outputs are kept in the tool's own history and are NOT added
/// to the main Library.
Future<List<String>> pickSourceFiles(
  BuildContext context, {
  required bool allowMultiple,
  List<String> extensions = const ['pdf'],
}) async {
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: extensions,
    allowMultiple: allowMultiple,
  );

  if (result == null) return [];

  final paths = <String>[];
  for (final f in result.files) {
    if (f.path != null) {
      paths.add(f.path!);
    }
  }

  return paths;
}
