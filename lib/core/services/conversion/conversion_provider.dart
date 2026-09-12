import 'dart:io';

import '../file_storage_service.dart';
import 'conversion_types.dart';

/// A pluggable backend that turns a file from one [ConversionFormat] into
/// another using a real cloud conversion service.
///
/// Every tool screen that needs PDF <-> Office conversion talks only to
/// this interface — never to a specific vendor's API directly. That means
/// swapping providers (or adding a second one and letting the user choose)
/// is a change in [resolveConversionProvider] (see conversion_service.dart)
/// plus one new class implementing this interface; no tool screen changes.
abstract class ConversionProvider {
  /// Stable identifier stored in prefs (see
  /// `AppDataController.conversionProviderId`) to select this provider.
  String get id;

  /// Shown in Settings and in error messages.
  String get displayName;

  /// Whether this provider currently has what it needs (an API key, etc.)
  /// to attempt a conversion. Checked before showing a "Convert" button as
  /// enabled, so the user isn't sent through an upload just to hit a
  /// configuration error at the end.
  bool get isConfigured;

  /// Converts the file at [sourcePath] and returns the converted file,
  /// already written into [storage]'s tmp directory as [outputFileName].
  ///
  /// Throws [ConversionException] for anything the caller should show to
  /// the user directly (missing/rejected API key, network failure, a
  /// server-side conversion error, an unexpected response shape). Never
  /// returns a fabricated or partial result — a thrown exception is always
  /// the correct outcome for anything that didn't genuinely convert.
  Future<File> convert({
    required String sourcePath,
    required ConversionFormat sourceFormat,
    required ConversionFormat targetFormat,
    required String outputFileName,
    required FileStorageService storage,
    void Function(ConversionPhase phase)? onPhase,
  });
}
