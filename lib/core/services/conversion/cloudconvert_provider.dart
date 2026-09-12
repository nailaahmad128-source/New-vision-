import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../file_storage_service.dart';
import 'conversion_provider.dart';
import 'conversion_types.dart';

/// Converts files using the real CloudConvert v2 REST API
/// (https://cloudconvert.com/api/v2): create a job with import/upload ->
/// convert -> export/url tasks, upload the source file to the presigned
/// form CloudConvert returns, wait for the job, then download the result.
///
/// Every failure mode is surfaced as a [ConversionException] rather than
/// silently producing nothing or faking success — a missing/rejected key,
/// a network error, a server-side conversion error, and a timeout are all
/// distinguished so the UI can react correctly (offer Settings vs Retry).
class CloudConvertProvider implements ConversionProvider {
  final String? apiKey;
  final http.Client _client;

  CloudConvertProvider({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  static const _base = 'https://api.cloudconvert.com/v2';

  @override
  String get id => 'cloudconvert';

  @override
  String get displayName => 'CloudConvert';

  @override
  bool get isConfigured => (apiKey ?? '').trim().isNotEmpty;

  @override
  Future<File> convert({
    required String sourcePath,
    required ConversionFormat sourceFormat,
    required ConversionFormat targetFormat,
    required String outputFileName,
    required FileStorageService storage,
    void Function(ConversionPhase phase)? onPhase,
  }) async {
    final key = apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw const ConversionException(
        'No cloud conversion API key is configured yet. Add one in Settings to use PDF ↔ Office conversion.',
        isConfigurationError: true,
      );
    }
    final headers = {
      'Authorization': 'Bearer $key',
      'Content-Type': 'application/json',
    };

    onPhase?.call(ConversionPhase.uploading);
    final job = await _createJob(headers, sourceFormat, targetFormat);
    final uploadTask = (job['tasks'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (t) => t['operation'] == 'import/upload',
          orElse: () => throw const ConversionException(
            'The conversion service did not return an upload target.',
          ),
        );
    await _uploadFile(uploadTask, sourcePath);

    onPhase?.call(ConversionPhase.converting);
    final jobId = job['id'] as String;
    final finishedJob = await _waitForJob(jobId, headers);

    if (finishedJob['status'] == 'error') {
      final failedTask = (finishedJob['tasks'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((t) => t['status'] == 'error', orElse: () => const {});
      throw ConversionException(
        (failedTask['message'] as String?) ?? 'The conversion failed on the server.',
      );
    }

    final exportTask = (finishedJob['tasks'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere(
          (t) => t['operation'] == 'export/url' && t['status'] == 'finished',
          orElse: () => throw const ConversionException(
            'The conversion service did not return a downloadable file.',
          ),
        );
    final files = (exportTask['result']?['files'] as List?)
            ?.cast<Map<String, dynamic>>() ??
        const [];
    if (files.isEmpty) {
      throw const ConversionException(
        'The conversion service did not return a downloadable file.',
      );
    }
    final fileUrl = files.first['url'] as String;

    onPhase?.call(ConversionPhase.downloading);
    final downloaded = await _download(fileUrl);

    final outFile = await storage.newTmpFile(outputFileName);
    await outFile.writeAsBytes(downloaded, flush: true);
    return outFile;
  }

  Future<Map<String, dynamic>> _createJob(
    Map<String, String> headers,
    ConversionFormat sourceFormat,
    ConversionFormat targetFormat,
  ) async {
    http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('$_base/jobs'),
            headers: headers,
            body: jsonEncode({
              'tasks': {
                'upload-file': {'operation': 'import/upload'},
                'convert-file': {
                  'operation': 'convert',
                  'input': 'upload-file',
                  'input_format': sourceFormat.apiFormat,
                  'output_format': targetFormat.apiFormat,
                },
                'export-file': {
                  'operation': 'export/url',
                  'input': 'convert-file',
                },
              },
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw ConversionException('Could not reach the conversion service: $e');
    }

    if (resp.statusCode == 401 || resp.statusCode == 403) {
      throw const ConversionException(
        'The cloud conversion API key was rejected. Check the key in Settings.',
        isConfigurationError: true,
      );
    }
    if (resp.statusCode >= 400) {
      throw ConversionException(_extractError(resp) ??
          'The conversion service returned an error (${resp.statusCode}).');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return decoded['data'] as Map<String, dynamic>;
  }

  Future<void> _uploadFile(Map<String, dynamic> uploadTask, String sourcePath) async {
    final form = uploadTask['result']?['form'] as Map<String, dynamic>?;
    if (form == null) {
      throw const ConversionException(
        'The conversion service did not return an upload target.',
      );
    }
    final uploadUrl = form['url'] as String;
    final parameters = Map<String, dynamic>.from(form['parameters'] as Map? ?? {});

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw ConversionException('The source file could not be found at $sourcePath.');
    }

    try {
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      // Plain fields must come before the file field — http's
      // MultipartRequest always encodes `fields` ahead of `files`
      // regardless of call order, which matches CloudConvert's requirement
      // that "file" be the last part of the multipart body.
      parameters.forEach((key, value) => request.fields[key] = value.toString());
      request.files.add(await http.MultipartFile.fromPath(
        'file',
        sourcePath,
        filename: p.basename(sourcePath),
      ));
      final streamed = await _client.send(request).timeout(const Duration(minutes: 3));
      if (streamed.statusCode >= 400) {
        final body = await streamed.stream.bytesToString();
        throw ConversionException(
          'The file upload failed (${streamed.statusCode}). ${body.isNotEmpty ? body : ''}'.trim(),
        );
      }
    } on ConversionException {
      rethrow;
    } on Exception catch (e) {
      throw ConversionException('The file upload failed: $e');
    }
  }

  Future<Map<String, dynamic>> _waitForJob(String jobId, Map<String, String> headers) async {
    http.Response waitResp;
    try {
      waitResp = await _client
          .get(Uri.parse('$_base/jobs/$jobId/wait'), headers: headers)
          .timeout(const Duration(minutes: 3));
    } on Exception catch (e) {
      throw ConversionException('Timed out waiting for the conversion to finish: $e');
    }
    if (waitResp.statusCode >= 400) {
      throw ConversionException(_extractError(waitResp) ??
          'The conversion service returned an error (${waitResp.statusCode}).');
    }
    var job = (jsonDecode(waitResp.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;

    // /jobs/{id}/wait is meant to block until the job finishes, but a very
    // large document can outlast it. Poll a little longer defensively
    // rather than treating an early return as a hard failure.
    var attempts = 0;
    while (job['status'] == 'processing' && attempts < 40) {
      await Future.delayed(const Duration(seconds: 3));
      http.Response pollResp;
      try {
        pollResp = await _client
            .get(Uri.parse('$_base/jobs/$jobId'), headers: headers)
            .timeout(const Duration(seconds: 30));
      } on Exception catch (e) {
        throw ConversionException('Lost connection while waiting for the conversion: $e');
      }
      if (pollResp.statusCode >= 400) {
        throw ConversionException(_extractError(pollResp) ??
            'The conversion service returned an error (${pollResp.statusCode}).');
      }
      job = (jsonDecode(pollResp.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      attempts++;
    }
    if (job['status'] == 'processing') {
      throw const ConversionException(
        'The conversion is taking longer than expected. Please try again in a moment.',
      );
    }
    return job;
  }

  Future<List<int>> _download(String url) async {
    http.Response resp;
    try {
      resp = await _client.get(Uri.parse(url)).timeout(const Duration(minutes: 2));
    } on Exception catch (e) {
      throw ConversionException('Could not download the converted file: $e');
    }
    if (resp.statusCode >= 400) {
      throw ConversionException(
        'Could not download the converted file (${resp.statusCode}).',
      );
    }
    return resp.bodyBytes;
  }

  String? _extractError(http.Response resp) {
    try {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      return json['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}
