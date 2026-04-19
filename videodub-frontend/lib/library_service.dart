import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'user_service.dart';
import 'notification_service.dart';

enum JobStatus { queued, processing, done, failed, cancelled }

class VideoJob {
  final String videoId;
  final String userId;
  String name;
  final String sourceLanguage;
  final String targetLanguage;
  final String originalPath;
  JobStatus status;
  int progress;
  String? dubbedPath;
  final DateTime createdAt;

  VideoJob({
    required this.videoId,
    required this.userId,
    required this.name,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.originalPath,
    this.status = JobStatus.processing,
    this.progress = 0,
    this.dubbedPath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isInProgress =>
      status == JobStatus.queued || status == JobStatus.processing;
  bool get isDone => status == JobStatus.done;

  Map<String, dynamic> toJson() => {
        'videoId': videoId,
        'userId': userId,
        'name': name,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'originalPath': originalPath,
        'status': status.name,
        'progress': progress,
        'dubbedPath': dubbedPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VideoJob.fromJson(Map<String, dynamic> json) => VideoJob(
        videoId: json['videoId'],
        userId: json['userId'],
        name: json['name'],
        sourceLanguage: json['sourceLanguage'],
        targetLanguage: json['targetLanguage'],
        originalPath: json['originalPath'] ?? '',
        status: JobStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => JobStatus.processing,
        ),
        progress: json['progress'] ?? 0,
        dubbedPath: json['dubbedPath'],
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      );
}

class LibraryService {
  static const _storageKey = 'video_jobs';
  static const _pollInterval = Duration(seconds: 30);

  static LibraryService? _instance;
  static LibraryService get instance => _instance ??= LibraryService._();
  LibraryService._();

  final List<VideoJob> _jobs = [];
  Timer? _pollTimer;

  final List<VoidCallback> _listeners = [];
  void addListener(VoidCallback listener) => _listeners.add(listener);
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
  void _notify() { for (final l in _listeners) l(); }

  List<VideoJob> get inProgressJobs => _jobs.where((j) => j.isInProgress).toList();
  List<VideoJob> get doneJobs => _jobs.where((j) => j.isDone).toList();

  // ── Get app storage dir ──────────────────────────────────────────

  Future<String> get _storageDir async {
    final dir = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${dir.path}/videos');
    if (!await videosDir.exists()) await videosDir.create(recursive: true);
    return videosDir.path;
  }

  // ── Copy original video to app storage ──────────────────────────

  Future<String> copyOriginalToStorage(String sourcePath, String videoId) async {
    final dir = await _storageDir;
    final ext = sourcePath.contains('.') ? '.${sourcePath.split('.').last}' : '.mp4';
    final destPath = '$dir/${videoId}_original$ext';
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  // ── Init ────────────────────────────────────────────────────────

  Future<void> init() async {
    await _loadFromStorage();
    _startPolling();
  }

  // ── Add job ─────────────────────────────────────────────────────

  Future<void> addJob({
    required String videoId,
    required String name,
    required String sourceLanguage,
    required String targetLanguage,
    required String originalPath,
  }) async {
    final userService = await UserService.getInstance();
    final userId = await userService.getUserId();

    final storedOriginalPath = await copyOriginalToStorage(originalPath, videoId);

    // Append timestamp to name to ensure uniqueness
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = name.contains('.') ? '.${name.split('.').last}' : '.mp4';
    final baseName = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    final uniqueName = '${baseName}_$ts$ext';

    final job = VideoJob(
      videoId: videoId,
      userId: userId,
      name: uniqueName,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      originalPath: storedOriginalPath,
    );

    _jobs.add(job);
    await _saveToStorage();
    _notify();
  }

  // ── Cancel job ──────────────────────────────────────────────────

  Future<void> cancelJob(String videoId) async {
    final job = _jobs.firstWhere((j) => j.videoId == videoId,
        orElse: () => throw Exception('Job not found'));

    await ApiService.instance.cancelJob(videoId: videoId, userId: job.userId);
    _deleteJobFiles(job);
    _jobs.removeWhere((j) => j.videoId == videoId);
    await _saveToStorage();
    _notify();
  }

  // ── Delete done job ─────────────────────────────────────────────

  Future<void> deleteDoneJob(String videoId) async {
    final job = _jobs.firstWhere((j) => j.videoId == videoId,
        orElse: () => throw Exception('Job not found'));
    _deleteJobFiles(job);
    _jobs.removeWhere((j) => j.videoId == videoId);
    await _saveToStorage();
    _notify();
  }

  void _deleteJobFiles(VideoJob job) {
    for (final path in [job.originalPath, job.dubbedPath]) {
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }
  }

  // ── Rename job ──────────────────────────────────────────────────

  Future<void> renameJob(String videoId, String newName) async {
    final job = _jobs.firstWhere((j) => j.videoId == videoId,
        orElse: () => throw Exception('Job not found'));
    job.name = newName;
    await _saveToStorage();
    _notify();
  }

  // ── Foreground polling ───────────────────────────────────────────

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollAll());
    _pollAll();
  }

  Future<void> _pollAll() async {
    final inProgress = inProgressJobs;
    if (inProgress.isEmpty) return;

    bool changed = false;

    for (final job in inProgress) {
      final result = await ApiService.instance.getStatus(
        videoId: job.videoId,
        userId: job.userId,
      );

      if (!result.success) continue;

      if (result.progress != job.progress) {
        job.progress = result.progress;
        changed = true;
      }

      if (result.isDone && job.status != JobStatus.done) {
        await _downloadDubbedVideo(job, result.downloadUrl!);
        changed = true;
      } else if (result.isFailed) {
        job.status = JobStatus.failed;
        await NotificationService.showVideoFailed(job.name);
        changed = true;
      }
    }

    if (changed) {
      await _saveToStorage();
      _notify();
    }
  }

  Future<void> _downloadDubbedVideo(VideoJob job, String downloadUrl) async {
    try {
      final dir = await _storageDir;
      final savePath = '$dir/${job.videoId}_dubbed.mp4';

      final result = await ApiService.instance.downloadVideo(
        videoId: job.videoId,
        userId: job.userId,
        savePath: savePath,
      );

      if (result.success) {
        job.dubbedPath = result.filePath;
        job.status = JobStatus.done;
        job.progress = 100;
        await NotificationService.showVideoReady(job.name);
      } else {
        job.status = JobStatus.failed;
        await NotificationService.showVideoFailed(job.name);
      }
    } catch (e) {
      job.status = JobStatus.failed;
      await NotificationService.showVideoFailed(job.name);
    }
  }

  // ── Persistence ─────────────────────────────────────────────────

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _jobs.map((j) => jsonEncode(j.toJson())).toList();
    await prefs.setStringList(_storageKey, jsonList);
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_storageKey) ?? [];
    _jobs.clear();
    for (final jsonStr in jsonList) {
      try { _jobs.add(VideoJob.fromJson(jsonDecode(jsonStr))); } catch (_) {}
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _listeners.clear();
  }
}

typedef VoidCallback = void Function();