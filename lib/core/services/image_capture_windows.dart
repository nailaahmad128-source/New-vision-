import 'package:file_picker/file_picker.dart';

Future<List<String>> pickImagesFromGallery() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: true,
  );
  return result?.files
          .where((file) => file.path != null)
          .map((file) => file.path!)
          .toList() ??
      const <String>[];
}

Future<String?> pickImageFromCamera() async {
  // Windows has no built-in system camera picker.
  return null;
}
