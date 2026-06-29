// lib/core/services/model_manager_web.dart
//
// Web stub — file system operations are not available in the browser.
// All methods return safe no-op values. Exported conditionally from model_manager.dart.

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

  Future<bool> isReady(String modelId) async => false;

  Future<ModelPaths?> getPaths(String modelId) async => null;

  Future<int> diskBytes(String modelId) async => 0;

  Stream<ModelDownloadProgress> download(String modelId) => const Stream.empty();

  Future<ModelPaths> ensureModel(
    String modelId, {
    void Function(ModelDownloadProgress)? onProgress,
  }) =>
      Future.error(UnsupportedError('On-device ASR models are not available on web'));

  Future<void> deleteModel(String modelId) async {}
}
