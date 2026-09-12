import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Decoding a rasterized PDF page and re-encoding it as JPEG is real CPU
/// work — for a multi-page PDF (Reorder/Rotate thumbnails, Compress,
/// PDF to Image) doing this synchronously on the UI isolate causes
/// visible jank or dropped frames. [compute] runs it on a background
/// isolate instead, one page at a time, so the UI stays responsive
/// while a large document is processed.
class _EncodeArgs {
  final Uint8List pngBytes;
  final int quality;
  final int? resizeWidth;
  const _EncodeArgs(this.pngBytes, this.quality, this.resizeWidth);
}

Uint8List? _decodeAndEncodeJpg(_EncodeArgs args) {
  final decoded = img.decodeImage(args.pngBytes);
  if (decoded == null) return null;
  final target = args.resizeWidth != null && decoded.width > args.resizeWidth!
      ? img.copyResize(decoded, width: args.resizeWidth)
      : decoded;
  return Uint8List.fromList(img.encodeJpg(target, quality: args.quality));
}

/// Decodes [pngBytes] and re-encodes as JPEG on a background isolate.
/// Returns null if the bytes couldn't be decoded as an image.
Future<Uint8List?> encodeJpgInBackground(
  Uint8List pngBytes, {
  int quality = 80,
  int? resizeWidth,
}) {
  return compute(_decodeAndEncodeJpg, _EncodeArgs(pngBytes, quality, resizeWidth));
}

/// Pixel size of a decoded image. Used by the scanner's corner-adjustment
/// screen to map normalized (0..1) corner points onto the actual rendered
/// image rect without guessing an aspect ratio first.
class ImageDimensions {
  final int width;
  final int height;
  const ImageDimensions(this.width, this.height);
}

ImageDimensions? _decodeDimensions(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  return ImageDimensions(decoded.width, decoded.height);
}

/// Decodes [bytes] on a background isolate and returns just its width and
/// height, so a full-page-sized scan doesn't block the UI thread while the
/// corner-adjustment screen figures out how to lay out its drag handles.
Future<ImageDimensions?> decodeImageDimensionsInBackground(Uint8List bytes) {
  return compute(_decodeDimensions, bytes);
}
