class OcrCancelledException implements Exception { const OcrCancelledException(); }
class OcrCancelToken { bool _cancelled = false; bool get isCancelled => _cancelled; void cancel() => _cancelled = true; }
class OcrService {
  Future<String> extractText(String path, {String language = 'auto', OcrCancelToken? cancelToken, void Function(int current, int total)? onProgress}) async {
    if (cancelToken?.isCancelled == true) throw const OcrCancelledException();
    onProgress?.call(1, 1);
    throw UnsupportedError('OCR on Windows will be enabled with the desktop OCR engine in a future build.');
  }
  Future<void> dispose() async {}
}
