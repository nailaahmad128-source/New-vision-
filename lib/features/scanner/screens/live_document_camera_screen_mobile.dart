import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

enum ScannerMode {
  document,
  idCard,
  book,
  qr,
}

class LiveDocumentCameraScreen extends StatefulWidget {
  const LiveDocumentCameraScreen({
    super.key,
    this.initialMode,
  });

  final ScannerMode? initialMode;

  @override
  State<LiveDocumentCameraScreen> createState() =>
      _LiveDocumentCameraScreenState();
}

class _LiveDocumentCameraScreenState
    extends State<LiveDocumentCameraScreen> {
  ScannerMode _mode = ScannerMode.document;

  bool _starting = false;
  bool _qrDetected = false;
  String? _qrText;

  final MobileScannerController _qrController =
      MobileScannerController();

  @override
  void initState() {
    super.initState();

    _mode = widget.initialMode ?? ScannerMode.document;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (_mode == ScannerMode.qr) {
        return;
      }

      _startGoogleScanner();
    });
  }

  Future<void> _startGoogleScanner() async {
    if (_starting || !mounted) return;

    _starting = true;

    try {
      /*
       * Google ML Kit Document Scanner
       *
       * The complete scanner UI, live document detection,
       * automatic capture, crop, rotation, filters, gallery
       * import and result generation are handled by Google's
       * native document scanner.
       *
       * One page is returned to the existing SmartScanner page.
       * Additional pages can be added from SmartScanner.
       */
      final options = DocumentScannerOptions(
        documentFormats: const {
          DocumentFormat.jpeg,
          DocumentFormat.pdf,
        },
        mode: ScannerMode.full,
        pageLimit: 1,
        isGalleryImport: true,
      );

      final scanner = DocumentScanner(
        options: options,
      );

      try {
        final result = await scanner.scanDocument();

        if (!mounted) return;

        final images = result.images;

        if (images != null && images.isNotEmpty) {
          final path = images.first;

          if (path.isNotEmpty && await File(path).exists()) {
            Navigator.of(context).pop(
              XFile(path),
            );
            return;
          }
        }

        /*
         * We intentionally return the JPEG image to the existing
         * Flutter scanner/editor pipeline. PDF generation remains
         * handled by SmartScanner so the existing Library/PDF/OCR
         * workflow is not broken.
         */
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No scanned image was returned. Please try again.',
              ),
            ),
          );
        }
      } finally {
        await scanner.close();
      }
    } catch (e) {
      if (!mounted) return;

      final message = e.toString();

      /*
       * Cancellation is normal when the user closes Google's
       * scanner. Do not show an alarming error for cancellation.
       */
      if (!message.toLowerCase().contains('cancel')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Document scanner could not start: $e',
            ),
          ),
        );
      }
    } finally {
      _starting = false;
    }
  }

  void _handleQr(BarcodeCapture capture) {
    if (!mounted || capture.barcodes.isEmpty) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;

      if (value != null && value.trim().isNotEmpty) {
        setState(() {
          _qrDetected = true;
          _qrText = value;
        });
        break;
      }
    }
  }

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mode != ScannerMode.qr) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF01D7A5),
          ),
        ),
      );
    }

    return _buildQrScanner();
  }

  Widget _buildQrScanner() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _qrController,
            onDetect: _handleQr,
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    0,
                  ),
                  child: Row(
                    children: [
                      _circleButton(
                        Icons.close_rounded,
                        () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      const Text(
                        'ScanFlow',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      _circleButton(
                        Icons.flash_on_rounded,
                        () => _qrController.toggleTorch(),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0xFF01D7A5),
                        width: 4,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                if (_qrDetected && _qrText != null)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 24,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF01D7A5),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'QR Code detected',
                          style: TextStyle(
                            color: Color(0xFF01D7A5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _qrText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _qrText!),
                            );

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text('Copied'),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Color(0xFF01D7A5),
                          ),
                          label: const Text(
                            'Copy',
                            style: TextStyle(
                              color: Color(0xFF01D7A5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 30),

                const Text(
                  'Point the camera at a QR code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.black.withValues(alpha: .55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
