import 'package:document_camera_frame/document_camera_frame.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Native document scanner bridge.
///
/// The actual camera/scanning experience is delegated to the platform-native
/// document scanner through document_camera_frame's CamScannerService.
/// The rest of PDF Master Tools continues to use XFile as before.
class LiveDocumentCameraScreen extends StatefulWidget {
  const LiveDocumentCameraScreen({super.key});

  @override
  State<LiveDocumentCameraScreen> createState() =>
      _LiveDocumentCameraScreenState();
}

class _LiveDocumentCameraScreenState
    extends State<LiveDocumentCameraScreen> {
  bool _opening = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openNativeScanner();
    });
  }

  Future<void> _openNativeScanner() async {
    if (_opening || !mounted) return;

    setState(() {
      _opening = true;
      _error = null;
    });

    try {
      final service = CamScannerService();

      // One page per capture keeps the existing Smart Scanner workflow:
      // Scan -> edit -> Add another page.
      final paths = await service.scan(maxPages: 1);

      if (!mounted) return;

      if (paths.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      final path = paths.first.trim();

      if (path.isEmpty) {
        Navigator.of(context).pop();
        return;
      }

      Navigator.of(context).pop(XFile(path));
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _opening = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan Document'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.document_scanner_outlined,
                  color: Colors.white,
                  size: 56,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Could not open the document scanner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _openNativeScanner,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
