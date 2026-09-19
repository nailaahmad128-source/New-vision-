import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class LiveDocumentCameraScreen extends StatelessWidget {
  const LiveDocumentCameraScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Desktop Scanner')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.document_scanner_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 18),
          const Text('Windows Scanner', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          const Text('On Windows, select a document image instead of using the phone camera.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              final r = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
              final path = r?.files.single.path;
              if (path != null && context.mounted) Navigator.pop(context, XFile(path));
            },
            icon: const Icon(Icons.folder_open_rounded), label: const Text('Choose document image'),
          ),
        ]),
      ),
    ),
  );
}

