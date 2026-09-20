import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart'
    show canLaunchUrl, launchUrl, LaunchMode;

import '../../../core/constants/tools_catalog.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../models/tool_history_entry.dart';
import '../../tools/widgets/tool_history_list.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  CameraController? _camera;
  late final BarcodeScanner _scanner;

  bool _initializing = true;
  bool _processing = false;
  bool _torchOn = false;
  String? _error;
  String? _lastValue;

  @override
  void initState() {
    super.initState();

    _scanner = BarcodeScanner(
      formats: const [
        BarcodeFormat.qrCode,
      ],
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      CameraDescription selected = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selected = camera;
          break;
        }
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _camera = controller;

      await controller.startImageStream(_processCameraImage);

      setState(() {
        _initializing = false;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = _cameraError(e);
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _initializing = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String _cameraError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Camera permission is required to scan QR codes.';
      default:
        return e.description ?? 'Could not start the camera.';
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_processing || !mounted || _camera == null) return;

    _processing = true;

    try {
      final controller = _camera!;
      final rotation =
          InputImageRotationValue.fromRawValue(
            controller.description.sensorOrientation,
          );

      if (rotation == null) return;

      final bytes = _yuv420ToNv21(image);

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(
            image.width.toDouble(),
            image.height.toDouble(),
          ),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );

      final barcodes = await _scanner.processImage(inputImage);

      for (final barcode in barcodes) {
        final value = barcode.rawValue?.trim();

        if (value != null && value.isNotEmpty) {
          await _handleDetectedCode(value);
          break;
        }
      }
    } catch (_) {
      // Camera frames arrive continuously. A bad individual frame
      // should never stop the scanner.
    } finally {
      _processing = false;
    }
  }

  Uint8List _yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final out = Uint8List(width * height + (width * height ~/ 2));
    var offset = 0;

    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;

      for (var col = 0; col < width; col++) {
        out[offset++] = yPlane.bytes[rowStart + col];
      }
    }

    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;

    for (var row = 0; row < uvHeight; row++) {
      for (var col = 0; col < uvWidth; col++) {
        final uIndex =
            row * uPlane.bytesPerRow +
            col * uPlane.bytesPerPixel!;
        final vIndex =
            row * vPlane.bytesPerRow +
            col * vPlane.bytesPerPixel!;

        out[offset++] = vPlane.bytes[vIndex];
        out[offset++] = uPlane.bytes[uIndex];
      }
    }

    return out;
  }

  Future<void> _handleDetectedCode(String value) async {
    if (!mounted || value == _lastValue) return;

    _lastValue = value;
    HapticFeedback.mediumImpact();

    try {
      await _camera?.stopImageStream();
    } catch (_) {}

    if (!mounted) return;

    _logScan(value);
    _showResultSheet(value);
  }

  Future<void> _restartScanning() async {
    _lastValue = null;

    final camera = _camera;

    if (camera == null || !camera.value.isInitialized) {
      return;
    }

    try {
      if (!camera.value.isStreamingImages) {
        await camera.startImageStream(_processCameraImage);
      }
    } catch (_) {}
  }

  Future<void> _toggleTorch() async {
    final camera = _camera;

    if (camera == null || !camera.value.isInitialized) return;

    try {
      _torchOn = !_torchOn;

      await camera.setFlashMode(
        _torchOn ? FlashMode.torch : FlashMode.off,
      );

      if (mounted) setState(() {});
    } catch (_) {
      _torchOn = false;
      if (mounted) setState(() {});
    }
  }

  void _logScan(String value) {
    final storage = context.read<FileStorageService>();
    final data = context.read<AppDataController>();

    final title =
        value.length > 60 ? '${value.substring(0, 60)}…' : value;

    data.addHistoryEntry(
      ToolHistoryEntry(
        id: storage.newId(),
        toolId: ToolId.qrScan.name,
        title: title,
        createdAt: DateTime.now(),
        success: true,
        note: value,
      ),
    );
  }

  void _showResultSheet(String value) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'QR Code detected',
                    style: Theme.of(ctx).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SelectableText(
                value,
                style: Theme.of(ctx).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_looksLikeUrl(value))
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse(value);

                          if (uri != null &&
                              await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open'),
                      ),
                    ),
                  if (_looksLikeUrl(value))
                    const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Share.share(value),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _restartScanning();
                  },
                  child: const Text('Scan again'),
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() async {
      if (mounted && _lastValue != null) {
        await _restartScanning();
      }
    });
  }

  bool _looksLikeUrl(String value) {
    return value.startsWith('http://') ||
        value.startsWith('https://');
  }

  @override
  void dispose() {
    _camera?.dispose();
    _scanner.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('QR Scanner'),
        actions: [
          if (camera != null &&
              camera.value.isInitialized &&
              !_initializing)
            IconButton(
              icon: Icon(
                _torchOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
              ),
              tooltip: 'Torch',
              onPressed: _toggleTorch,
            ),
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Scan history',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ToolHistoryScreen(
                    toolId: ToolId.qrScan,
                    title: 'Scan History',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 72,
              ),
              const SizedBox(height: 20),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _initializing = true;
                    _error = null;
                  });
                  _initializeCamera();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final camera = _camera;

    if (camera == null || !camera.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera is not available.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(camera),

        IgnorePointer(
          child: Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: CustomPaint(
                painter: _QrFramePainter(),
              ),
            ),
          ),
        ),

        Positioned(
          left: 24,
          right: 24,
          bottom: 34,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Point the camera at a QR code',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QrFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const corner = 38.0;

    final path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, 0)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, corner)
      ..moveTo(0, size.height - corner)
      ..lineTo(0, size.height)
      ..lineTo(corner, size.height)
      ..moveTo(size.width - corner, size.height)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width, size.height - corner);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
