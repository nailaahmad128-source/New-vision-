/// Document formats the conversion module knows how to move between.
/// Kept intentionally small — this only covers the PDF <-> Office triangle,
/// not every format a converter API might support.
enum ConversionFormat { pdf, docx, xlsx, pptx }

extension ConversionFormatX on ConversionFormat {
  /// The format identifier a conversion API expects (CloudConvert uses
  /// exactly these names for `input_format` / `output_format`).
  String get apiFormat => switch (this) {
        ConversionFormat.pdf => 'pdf',
        ConversionFormat.docx => 'docx',
        ConversionFormat.xlsx => 'xlsx',
        ConversionFormat.pptx => 'pptx',
      };

  String get fileExtension => '.$apiFormat';

  String get displayName => switch (this) {
        ConversionFormat.pdf => 'PDF',
        ConversionFormat.docx => 'Word (.docx)',
        ConversionFormat.xlsx => 'Excel (.xlsx)',
        ConversionFormat.pptx => 'PowerPoint (.pptx)',
      };

  /// Extensions the file picker should accept when choosing a source file
  /// in this format (includes the legacy extension where one exists).
  List<String> get pickerExtensions => switch (this) {
        ConversionFormat.pdf => const ['pdf'],
        ConversionFormat.docx => const ['docx', 'doc'],
        ConversionFormat.xlsx => const ['xlsx', 'xls'],
        ConversionFormat.pptx => const ['pptx', 'ppt'],
      };
}

/// Coarse-grained stage of a conversion in progress. Cloud converters don't
/// generally expose byte-level progress for the convert step itself, so the
/// UI shows which stage it's in rather than a fabricated percentage.
enum ConversionPhase { uploading, converting, downloading }

/// Thrown by anything in the conversion module. [isConfigurationError] is
/// set when the problem is something the user can fix in Settings (missing
/// or rejected API key) as opposed to a transient/network/server problem —
/// the UI uses this to decide whether to offer "Open Settings" or "Retry".
class ConversionException implements Exception {
  final String message;
  final bool isConfigurationError;
  const ConversionException(this.message, {this.isConfigurationError = false});

  @override
  String toString() => message;
}
