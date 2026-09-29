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
  final int? maxDimension;

  const _EncodeArgs(
    this.pngBytes,
    this.quality,
    this.resizeWidth,
    this.maxDimension,
  );
}

Uint8List? _decodeAndEncodeJpg(_EncodeArgs args) {
  final decoded = img.decodeImage(args.pngBytes);
  if (decoded == null) return null;
  var target = decoded;

  if (args.maxDimension != null &&
      (target.width > args.maxDimension! ||
          target.height > args.maxDimension!)) {
    if (target.width >= target.height) {
      target = img.copyResize(
        target,
        width: args.maxDimension!,
      );
    } else {
      target = img.copyResize(
        target,
        height: args.maxDimension!,
      );
    }
  } else if (args.resizeWidth != null &&
      target.width > args.resizeWidth!) {
    target = img.copyResize(
      target,
      width: args.resizeWidth,
    );
  }
  return Uint8List.fromList(img.encodeJpg(target, quality: args.quality));
}

/// Decodes [pngBytes] and re-encodes as JPEG on a background isolate.
/// Returns null if the bytes couldn't be decoded as an image.
Future<Uint8List?> encodeJpgInBackground(
  Uint8List pngBytes, {
  int quality = 80,
  int? resizeWidth,
}) {
  return compute(
    _decodeAndEncodeJpg,
    _EncodeArgs(
      pngBytes,
      quality,
      resizeWidth,
      null,
    ),
  );
}

Future<Uint8List?> normalizeImageForEditing(
  Uint8List bytes, {
  int maxDimension = 2200,
  int quality = 94,
}) {
  return compute(
    _normalizeForEditing,
    <String, dynamic>{
      'bytes': bytes,
      'maxDimension': maxDimension,
      'quality': quality,
    },
  );
}

Uint8List? _normalizeForEditing(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final maxDimension = args['maxDimension'] as int;
  final quality = args['quality'] as int;

  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  if (decoded.width <= maxDimension &&
      decoded.height <= maxDimension) {
    return bytes;
  }

  var target = decoded;

  if (target.width >= target.height) {
    target = img.copyResize(
      target,
      width: maxDimension,
    );
  } else {
    target = img.copyResize(
      target,
      height: maxDimension,
    );
  }

  return Uint8List.fromList(
    img.encodeJpg(target, quality: quality),
  );
}



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

Future<ImageDimensions?> decodeImageDimensionsInBackground(
  Uint8List bytes,
) {
  return compute(_decodeDimensions, bytes);
}


/// Applies scanner filters, brightness and contrast on a background isolate.
Uint8List _applyImageEdits(Map<String, dynamic> args) {
  final bytes = args['bytes'] as Uint8List;
  final filter = args['filter'] as int;
  final brightness = args['brightness'] as double;
  final contrast = args['contrast'] as double;

  var decoded = img.decodeImage(bytes);

  if (decoded == null) {
    return Uint8List.fromList(bytes);
  }

  const maxEditDimension = 2200;

  if (decoded.width > maxEditDimension ||
      decoded.height > maxEditDimension) {
    if (decoded.width >= decoded.height) {
      decoded = img.copyResize(
        decoded,
        width: maxEditDimension,
      );
    } else {
      decoded = img.copyResize(
        decoded,
        height: maxEditDimension,
      );
    }
  }

  switch (filter) {
    case 1:
      img.grayscale(decoded);
      break;
    case 2:
      img.grayscale(decoded);
      img.adjustColor(
        decoded,
        contrast: 1.35,
        brightness: 1.05,
      );
      break;
    case 3:
      img.grayscale(decoded);
      img.adjustColor(
        decoded,
        contrast: 1.75,
        brightness: 1.08,
      );
      img.convolution(
        decoded,
        filter: const [
          0, -1, 0,
          -1, 5, -1,
          0, -1, 0,
        ],
      );
      break;
    case 4:
      img.adjustColor(
        decoded,
        contrast: 1.22,
        brightness: 1.04,
        saturation: 0.92,
      );
      break;
  }

  img.adjustColor(
    decoded,
    brightness: brightness,
    contrast: contrast,
  );

  return Uint8List.fromList(
    img.encodeJpg(decoded, quality: 95),
  );
}

/// Runs scanner image editing away from the UI isolate.
Future<Uint8List> applyImageEditsInBackground({
  required Uint8List bytes,
  required int filter,
  required double brightness,
  required double contrast,
}) {
  return compute(
    _applyImageEdits,
    <String, dynamic>{
      'bytes': bytes,
      'filter': filter,
      'brightness': brightness,
      'contrast': contrast,
    },
  );
}
