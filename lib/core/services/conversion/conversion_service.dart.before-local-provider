import '../../storage/app_data_controller.dart';
import 'cloudconvert_provider.dart';
import 'conversion_provider.dart';

/// Resolves which [ConversionProvider] implementation handles PDF <-> Office
/// conversions right now.
///
/// CloudConvert is the only provider wired up today, but no tool screen
/// talks to it directly — every conversion goes through
/// [ConversionProvider], and this is the one place that picks a concrete
/// implementation. To add a second provider later (Adobe PDF Services,
/// ILovePDF, a self-hosted converter, ...):
///   1. Implement [ConversionProvider] in its own file in this folder.
///   2. Add one more `case` below, keyed off
///      [AppDataController.conversionProviderId].
///   3. Optionally add a picker in Settings that calls
///      `AppDataController.setConversionProviderId`.
/// No tool screen changes.
ConversionProvider resolveConversionProvider(AppDataController appData) {
  switch (appData.conversionProviderId) {
    case 'cloudconvert':
    default:
      return CloudConvertProvider(apiKey: appData.cloudConvertApiKey);
  }
}
