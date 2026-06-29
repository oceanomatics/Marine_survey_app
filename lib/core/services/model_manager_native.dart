// lib/core/services/model_manager_native.dart
//
// Native (Android/iOS/desktop) implementation — uses dart:io for file ops.
// Exported conditionally from model_manager.dart.

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

// ── Model catalog ─────────────────────────────────────────────────────────────

class SherpaModelConfig {
  const SherpaModelConfig({
    required this.id,
    required this.displayName,
    required this.quality,
    required this.description,
    required this.estimatedMb,
    required this.hfRepo,
    required this.files,
    this.modelType = 'zipformer',
  });

  final String id;
  final String displayName;
  final String quality;
  final String description;
  final int    estimatedMb;
  final String hfRepo;
  final Map<String, String> files;
  final String modelType;

  static const List<SherpaModelConfig> catalog = [
    SherpaModelConfig(
      id:          'en-20m',
      displayName: 'English — Fast',
      quality:     'Fast',
      description: 'Streaming Zipformer 20M · good accuracy · quick download',
      estimatedMb: 45,
      hfRepo:      'csukuangfj/sherpa-onnx-streaming-zipformer-en-20M-2023-02-17',
      files: {
        'encoder': 'encoder-epoch-99-avg-1.onnx',
        'decoder': 'decoder-epoch-99-avg-1.onnx',
        'joiner':  'joiner-epoch-99-avg-1.onnx',
        'tokens':  'tokens.txt',
      },
    ),
    SherpaModelConfig(
      id:          'en-large',
      displayName: 'English — Accurate',
      quality:     'Accurate',
      description: 'Streaming Zipformer full-size · best accuracy · larger download',
      estimatedMb: 170,
      hfRepo:      'csukuangfj/sherpa-onnx-streaming-zipformer-en-2023-06-26',
      files: {
        'encoder': 'encoder-epoch-99-avg-1-chunk-16-left-128.onnx',
        'decoder': 'decoder-epoch-99-avg-1-chunk-16-left-128.onnx',
        'joiner':  'joiner-epoch-99-avg-1-chunk-16-left-128.onnx',
        'tokens':  'tokens.txt',
      },
    ),
  ];

  static SherpaModelConfig byId(String id) =>
      catalog.firstWhere((m) => m.id == id, orElse: () => catalog.first);
}

// ── Progress ──────────────────────────────────────────────────────────────────

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.fileName,
    required this.fileIndex,
    required this.fileCount,
    required this.received,
    required this.total,
  });

  final String fileName;
  final int    fileIndex;
  final int    fileCount;
  final int    received;
  final int    total;

  double get fileFraction  => total > 0 ? received / total : 0;
  double get totalFraction => ((fileIndex - 1) + fileFraction) / fileCount;
}

// ── Paths ─────────────────────────────────────────────────────────────────────

class ModelPaths {
  const ModelPaths({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
  });
  final String encoder, decoder, joiner, tokens;
}

// ── Manager ───────────────────────────────────────────────────────────────────

class ModelManager {
  static final ModelManager instance = ModelManager._();
  ModelManager._();

  static const _root = 'sherpa_asr_model';

  Future<Directory> _dir(String modelId) async {
    final docs = await getApplicationDocumentsDirectory();
    final cfg  = SherpaModelConfig.byId(modelId);
    final dir  = Directory('${docs.path}/$_root/${cfg.hfRepo.split('/').last}');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<bool> isReady(String modelId) async =>
      (await getPaths(modelId)) != null;

  Future<ModelPaths?> getPaths(String modelId) async {
    final dir = await _dir(modelId);
    final cfg = SherpaModelConfig.byId(modelId);
    for (final filename in cfg.files.values) {
      final f = File('${dir.path}/$filename');
      if (!f.existsSync() || f.lengthSync() == 0) return null;
    }
    return ModelPaths(
      encoder: '${dir.path}/${cfg.files['encoder']}',
      decoder: '${dir.path}/${cfg.files['decoder']}',
      joiner:  '${dir.path}/${cfg.files['joiner']}',
      tokens:  '${dir.path}/${cfg.files['tokens']}',
    );
  }

  Future<int> diskBytes(String modelId) async {
    final dir = await _dir(modelId);
    if (!dir.existsSync()) return 0;
    int total = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) total += await entity.length();
    }
    return total;
  }

  Stream<ModelDownloadProgress> download(String modelId) async* {
    final dir     = await _dir(modelId);
    final cfg     = SherpaModelConfig.byId(modelId);
    final dio     = Dio();
    final base    = 'https://huggingface.co/${cfg.hfRepo}/resolve/main';
    final entries = cfg.files.entries.toList();

    for (int i = 0; i < entries.length; i++) {
      final filename = entries[i].value;
      final dest     = File('${dir.path}/$filename');

      if (dest.existsSync() && dest.lengthSync() > 0) {
        yield ModelDownloadProgress(
            fileName: filename, fileIndex: i + 1,
            fileCount: entries.length, received: 1, total: 1);
        continue;
      }

      final tmp  = File('${dest.path}.tmp');
      final sink = tmp.openWrite();
      int rx = 0, total = 0;

      try {
        final resp = await dio.get<ResponseBody>(
          '$base/$filename',
          options: Options(responseType: ResponseType.stream),
        );
        total = int.tryParse(
                    resp.headers.value('content-length') ?? '') ??
                0;

        await for (final chunk in resp.data!.stream) {
          sink.add(chunk);
          rx += chunk.length;
          yield ModelDownloadProgress(
            fileName:  filename,
            fileIndex: i + 1,
            fileCount: entries.length,
            received:  rx,
            total:     total > 0 ? total : rx,
          );
        }
        await sink.flush();
        await sink.close();
        await tmp.rename(dest.path);
      } catch (e) {
        await sink.close();
        if (tmp.existsSync()) tmp.deleteSync();
        rethrow;
      }
    }
  }

  Future<ModelPaths> ensureModel(
    String modelId, {
    void Function(ModelDownloadProgress)? onProgress,
  }) async {
    final existing = await getPaths(modelId);
    if (existing != null) return existing;

    await for (final p in download(modelId)) {
      onProgress?.call(p);
    }

    final paths = await getPaths(modelId);
    if (paths == null) throw Exception('Model download completed but files are missing');
    return paths;
  }

  Future<void> deleteModel(String modelId) async {
    final dir = await _dir(modelId);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
