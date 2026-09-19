import 'package:image_picker/image_picker.dart';

Future<List<String>> pickImagesFromGallery() async {
  final files = await ImagePicker().pickMultiImage(imageQuality: 95);
  return files.map((x) => x.path).toList();
}

Future<String?> pickImageFromCamera() async {
  final shot = await ImagePicker().pickImage(
    source: ImageSource.camera,
    imageQuality: 95,
  );
  return shot?.path;
}
