import 'package:file_picker/file_picker.dart';

Future<List<String>> pickImagesFromGallery() async {
  final files = await FilePicker.pickFiles(
    type: FileType.image,
  );

  return files
      .where((file) => file.path != null)
      .map((file) => file.path!)
      .toList();
}

Future<String?> pickImageFromCamera() async {
  // Windows has no built-in system camera picker.
  return null;
}
