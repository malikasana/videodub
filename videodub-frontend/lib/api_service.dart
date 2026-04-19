import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ApiService {
  // ── Config ──────────────────────────────────────────────────────
  // Emulator: http://10.0.2.2:8000
  // Real device on same WiFi: http://YOUR_PC_IP:8000
  // Deployed: https://your-domain.com
  // static const String _baseUrl = 'http://10.0.2.2:8000';
  static const String _baseUrl = 'http://192.168.18.3:8000';
  static const Duration _timeout = Duration(seconds: 30);

  static ApiService? _instance;
  ApiService._();
  static ApiService get instance => _instance ??= ApiService._();

  // ── Upload video ────────────────────────────────────────────────

  Future<UploadResult> uploadVideo({
    required String userId,
    required File videoFile,
    required String originalName,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload');
      final request = http.MultipartRequest('POST', uri);

      request.fields['user_id'] = userId;
      request.files.add(await http.MultipartFile.fromPath(
        'video',
        videoFile.path,
        filename: originalName,
      ));

      final streamedResponse = await request.send().timeout(_timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return UploadResult.success(
          videoId: data['video_id'],
          originalName: data['original_name'],
        );
      } else if (response.statusCode == 503) {
        return UploadResult.error('Server is busy. Please try again later.');
      } else {
        final data = jsonDecode(response.body);
        return UploadResult.error(data['detail'] ?? 'Upload failed');
      }
    } on SocketException {
      return UploadResult.error('Cannot connect to server. Check your connection.');
    } on TimeoutException {
      return UploadResult.error('Request timed out. Please try again.');
    } catch (e) {
      return UploadResult.error('Something went wrong. Please try again.');
    }
  }

  // ── Poll status ─────────────────────────────────────────────────

  Future<StatusResult> getStatus({
    required String videoId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/status/$videoId?user_id=$userId');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return StatusResult.success(
          status: data['status'],
          progress: data['progress'] ?? 0,
          downloadUrl: data['download_url'],
          originalName: data['original_name'],
        );
      } else if (response.statusCode == 404) {
        return StatusResult.error('Job not found');
      } else {
        return StatusResult.error('Failed to get status');
      }
    } on SocketException {
      return StatusResult.error('Cannot connect to server');
    } on TimeoutException {
      return StatusResult.error('Request timed out');
    } catch (e) {
      return StatusResult.error('Something went wrong');
    }
  }

  // ── Download dubbed video ───────────────────────────────────────

  Future<DownloadResult> downloadVideo({
    required String videoId,
    required String userId,
    required String savePath,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/download/$videoId?user_id=$userId');
      final response = await http.get(uri).timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);
        return DownloadResult.success(filePath: savePath);
      } else {
        return DownloadResult.error('Download failed');
      }
    } on SocketException {
      return DownloadResult.error('Cannot connect to server');
    } on TimeoutException {
      return DownloadResult.error('Download timed out');
    } catch (e) {
      return DownloadResult.error('Something went wrong');
    }
  }

  // ── Cancel job ──────────────────────────────────────────────────

  Future<bool> cancelJob({
    required String videoId,
    required String userId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/job/$videoId?user_id=$userId');
      final response = await http.delete(uri).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ── Result models ─────────────────────────────────────────────────

class UploadResult {
  final bool success;
  final String? videoId;
  final String? originalName;
  final String? error;

  UploadResult._({required this.success, this.videoId, this.originalName, this.error});

  factory UploadResult.success({required String videoId, required String originalName}) =>
      UploadResult._(success: true, videoId: videoId, originalName: originalName);

  factory UploadResult.error(String message) =>
      UploadResult._(success: false, error: message);
}

class StatusResult {
  final bool success;
  final String? status;
  final int progress;
  final String? downloadUrl;
  final String? originalName;
  final String? error;

  StatusResult._({
    required this.success,
    this.status,
    this.progress = 0,
    this.downloadUrl,
    this.originalName,
    this.error,
  });

  factory StatusResult.success({
    required String status,
    required int progress,
    String? downloadUrl,
    String? originalName,
  }) => StatusResult._(
        success: true,
        status: status,
        progress: progress,
        downloadUrl: downloadUrl,
        originalName: originalName,
      );

  factory StatusResult.error(String message) =>
      StatusResult._(success: false, error: message);

  bool get isDone => status == 'done';
  bool get isProcessing => status == 'processing' || status == 'queued';
  bool get isFailed => status == 'failed' || status == 'cancelled';
}

class DownloadResult {
  final bool success;
  final String? filePath;
  final String? error;

  DownloadResult._({required this.success, this.filePath, this.error});

  factory DownloadResult.success({required String filePath}) =>
      DownloadResult._(success: true, filePath: filePath);

  factory DownloadResult.error(String message) =>
      DownloadResult._(success: false, error: message);
}