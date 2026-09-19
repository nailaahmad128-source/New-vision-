import 'conversion_provider.dart';
import 'local_office_converter.dart';

/// Resolves the conversion engine used by PDF <-> Office tools.
///
/// PDF -> Word / Excel / PowerPoint is handled locally on the device.
/// No CloudConvert API key is required.
ConversionProvider resolveConversionProvider() {
  return const LocalOfficeConverter();
}
