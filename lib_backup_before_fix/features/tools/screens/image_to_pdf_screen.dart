import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/pdf_tools_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/empty_state.dart';
import '../widgets/tool_history_list.dart';
import '../widgets/tool_result_screen.dart';
import '../../../core/services/image_capture.dart';

class ImageToPdfScreen extends StatefulWidget {
  const ImageToPdfScreen({super.key});
  @override
  State<ImageToPdfScreen> createState() => _ImageToPdfScreenState();
}

class _ImageToPdfScreenState extends State<ImageToPdfScreen> {
  final List<String> _images = [];
  bool _working = false;

  Future<void> _addImages() async {
    final picked = await pickImagesFromGallery();
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked));
  }

  Future<void> _addFromCamera() async {
    // Desktop has no system camera picker. Use the native file picker on
    // Windows; Android/iOS keep the real camera flow through image_picker.
    if (Platform.isWindows) {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      final path = result?.single.path;
      if (path == null) return;
      setState(() => _images.add(path));
      return;
    }
    // image_picker is intentionally imported conditionally below through a
    // local helper on mobile; this branch is replaced by _addFromMobileCamera.
    await _addFromMobileCamera();
  }

  Future<void> _addFromMobileCamera() async {
    // Kept in a separate method so Windows never invokes ImageSource.camera.
    // The mobile implementation is provided by the conditional helper.
    final shot = await pickImageFromCamera();
    if (shot == null) return;
    setState(() => _images.add(shot));
  }

  Future<void> _convert() async {
    if (_images.isEmpty) return;
    setState(() => _working = true);
    try {
      final tools = context.read<PdfToolsService>();
      final data = context.read<AppDataController>();
      final outName = 'Scanned_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await tools.imagesToPdf(_images, outputName: outName);
      final pages = await tools.pageCount(file.path);
      final thumb = await tools.generateThumbnail(file.path, type: 'pdf');
      final doc = await data.registerToolResult(
        tmpFile: file,
        fileName: outName,
        toolId: ToolId.imageToPdf.name,
        toolTitle: 'PDF from ${_images.length} images',
        type: 'pdf',
        pageCount: pages,
      );
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ToolResultScreen(results: [doc], successTitle: 'PDF created!'),
      ));
      setState(() => _images.clear());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conversion failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image to PDF')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_images.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.image_rounded,
                  title: 'Add photos',
                  message: 'Pick photos from your gallery or take new ones — each becomes a page.',
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _images.length,
                itemBuilder: (ctx, i) => Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(File(_images[i]), fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 4, right: 4,
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(i)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                        child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addImages,
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _addFromCamera,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            if (_images.isNotEmpty) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _working ? null : _convert,
                  child: _working
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Create PDF (${_images.length})'),
                ),
              ),
            ],
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const ToolHistorySection(toolId: ToolId.imageToPdf),
          ],
        ),
      ),
    );
  }
}
