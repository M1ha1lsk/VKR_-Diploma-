import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'health_backend.dart';

class MlPredictionApiClient {
  MlPredictionApiClient({
    String? baseUrl,
    HttpClient? httpClient,
  })  : _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'ML_API_BASE_URL',
              defaultValue: 'http://10.0.2.2:8000',
            ),
        _httpClient = httpClient ?? HttpClient();

  final String _baseUrl;
  final HttpClient _httpClient;

  Future<Map<String, dynamic>> predict(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$_baseUrl/predict');
    final request = await _httpClient.postUrl(uri).timeout(
          const Duration(seconds: 8),
        );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(const Duration(seconds: 20));
    final body = await utf8.decodeStream(response);
    Map<String, dynamic> parsed;
    try {
      final raw = jsonDecode(body);
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Response is not a JSON object');
      }
      parsed = raw;
    } catch (_) {
      throw BackendRequestError('ML сервис вернул некорректный ответ.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final msg = parsed['detail']?.toString();
      throw BackendRequestError(msg ?? 'Ошибка ML сервиса (${response.statusCode}).');
    }
    return parsed;
  }
}
