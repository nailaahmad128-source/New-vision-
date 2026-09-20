import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Online OCR powered by OCR.space Engine 3.
///
/// This service is optional:
/// - Empty API key -> caller should use local OCR.
/// - Network/API failure -> caller should use local OCR fallback.
///
/// The API key is supplied at runtime and is never hard-coded here.
class OnlineOcrService {
  OnlineOcrService({
    required this.apiKey,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String _endpoint = 'https://api.ocr.space/parse/image';

  final String apiKey;
  final http.Client _client;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Extract text from an image or PDF using OCR.space Engine 3.
  ///
  /// [language]:
  /// - auto -> automatic language detection
  /// - urd -> Urdu
  /// - ara -> Arabic
  /// - eng -> English
  Future<String> extractText({
    required String filePath,
    String language = 'auto',
  }) async {
    if (!isConfigured) {
      throw const OnlineOcrNotConfiguredException();
    }

    final file = File(filePath);

    if (!await file.exists()) {
      throw OnlineOcrException('File not found: $filePath');
    }

    final normalizedLanguage = _normalizeLanguage(language);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse(_endpoint),
    );

    request.headers['apikey'] = apiKey.trim();
    request.fields['OCREngine'] = '3';
    request.fields['language'] = normalizedLanguage;
    request.fields['isOverlayRequired'] = 'false';
    request.fields['isTable'] = 'false';
    request.fields['scale'] = 'true';
    request.fields['detectOrientation'] = 'true';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
      ),
    );

    try {
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 90));

      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OnlineOcrException(
          'OCR.space HTTP ${response.statusCode}',
        );
      }

      return _parseResponse(response.body);
    } on SocketException catch (e) {
      throw OnlineOcrException(
        'Network error while connecting to OCR.space: $e',
      );
    } on http.ClientException catch (e) {
      throw OnlineOcrException(
        'OCR.space connection error: $e',
      );
    } on OnlineOcrException {
      rethrow;
    } catch (e) {
      throw OnlineOcrException(
        'Online OCR failed: $e',
      );
    }
  }

  String _parseResponse(String body) {
    dynamic decoded;

    try {
      decoded = jsonDecode(body);
    } catch (_) {
      throw const OnlineOcrException(
        'OCR.space returned an invalid response.',
      );
    }

    if (decoded is! Map) {
      throw const OnlineOcrException(
        'OCR.space returned an unexpected response.',
      );
    }

    final errorFlag = decoded['IsErroredOnProcessing'];

    if (errorFlag == true || errorFlag == 'true') {
      final errorMessage = decoded['ErrorMessage'];

      if (errorMessage is List && errorMessage.isNotEmpty) {
        throw OnlineOcrException(
          errorMessage.map((e) => e.toString()).join('\n'),
        );
      }

      throw OnlineOcrException(
        errorMessage?.toString() ?? 'OCR processing failed.',
      );
    }

    final parsedResults = decoded['ParsedResults'];

    if (parsedResults is! List) {
      throw const OnlineOcrException(
        'OCR.space returned no parsed results.',
      );
    }

    final parts = <String>[];

    for (final item in parsedResults) {
      if (item is! Map) continue;

      final text = item['ParsedText'];

      if (text is String && text.trim().isNotEmpty) {
        parts.add(text.trim());
      }
    }

    final result = parts.join('\n\n').trim();

    if (result.isEmpty) {
      throw const OnlineOcrException(
        'OCR.space could not recognize readable text.',
      );
    }

    return result;
  }

  String _normalizeLanguage(String language) {
    final value = language.trim().toLowerCase();

    switch (value) {
      case 'urd':
      case 'ur':
      case 'ur-pk':
        return 'urd';

      case 'ara':
      case 'ar':
      case 'ar-sa':
        return 'ara';

      case 'eng':
      case 'en':
      case 'en-us':
      case 'en-gb':
        return 'eng';

      case 'auto':
      case '':
        return 'auto';

      default:
        return value;
    }
  }

  void dispose() {
    _client.close();
  }
}

class OnlineOcrNotConfiguredException implements Exception {
  const OnlineOcrNotConfiguredException();

  @override
  String toString() => 'OCR.space API key is not configured.';
}

class OnlineOcrException implements Exception {
  const OnlineOcrException(this.message);

  final String message;

  @override
  String toString() => message;
}
