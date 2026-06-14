// lib/core/api/whisper_api.dart

import 'dart:io';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

class WhisperApi {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://api.openai.com/v1',
    headers: {'Authorization': 'Bearer ${AppConfig.openAiApiKey}'},
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 300), // long audio files
  ));

  /// Transcribe an audio file using OpenAI Whisper
  /// Supports: mp4, mp3, wav, m4a, webm, ogg
  /// Returns the full transcript text
  static Future<String> transcribe({
    required String audioFilePath,
    String language = 'en',
    String? prompt, // optional context to improve accuracy
  }) async {
    final file = File(audioFilePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $audioFilePath');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFilePath,
        filename: file.uri.pathSegments.last,
      ),
      'model': 'whisper-1',
      'language': language,
      'response_format': 'text',
      if (prompt != null) 'prompt': prompt,
    });

    final response = await _dio.post(
      '/audio/transcriptions',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
        responseType: ResponseType.plain,
      ),
    );

    return response.data?.toString().trim() ?? '';
  }

  /// Transcribe with timestamps (returns verbose JSON)
  /// Useful for interview recordings where you want segment timings
  static Future<Map<String, dynamic>> transcribeWithTimestamps({
    required String audioFilePath,
    String language = 'en',
    String? prompt,
  }) async {
    final file = File(audioFilePath);

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioFilePath,
        filename: file.uri.pathSegments.last,
      ),
      'model': 'whisper-1',
      'language': language,
      'response_format': 'verbose_json',
      'timestamp_granularities[]': 'segment',
      if (prompt != null) 'prompt': prompt,
    });

    final response = await _dio.post(
      '/audio/transcriptions',
      data: formData,
      options: Options(
        headers: {'Content-Type': 'multipart/form-data'},
      ),
    );

    return response.data as Map<String, dynamic>;
  }
}
