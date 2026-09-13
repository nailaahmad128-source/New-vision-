import 'dart:io';

import '../file_storage_service.dart';
import 'conversion_types.dart';

/// A pluggable backend for PDF and Office document conversion.
abstract class ConversionProvider {
  /// Stable identifier for this conversion provider.
  String get id;

  /// Human-readable provider name.
  String get displayName;

  /// Whether the provider is ready to perform conversions.
  bool get isConfigured;

  /// Converts the source file and returns the generated output file.
  ///
  /// Throws [ConversionException] if the conversion cannot be completed.
  Future<File> convert({
    required String sourcePath,
    required ConversionFormat sourceFormat,
    required ConversionFormat targetFormat,
    required String outputFileName,
    required FileStorageService storage,
    void Function(ConversionPhase phase)? onPhase,
  });
}
