import 'dart:convert';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'api_service.dart';

const _taskName = 'videodub_poll';
const _storageKey = 'video_jobs';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == _taskName) {
      await _backgroundPoll();
    }
    return true;
  });
}

Future<void> _backgroundPoll() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonList = prefs.getStringList(_storageKey) ?? [];
  if (jsonList.isEmpty) return;

  bool changed = false;
  final updatedList = <String>[];

  for (final jsonStr in jsonList) {
    try {
      final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
      final status = map['status'] as String? ?? '';

      if (status != 'processing' && status != 'queued') {
        updatedList.add(jsonStr);
        continue;
      }

      final videoId = map['videoId'] as String;
      final userId = map['userId'] as String;
      final name = map['name'] as String;

      final result = await ApiService.instance.getStatus(
        videoId: videoId,
        userId: userId,
      );

      if (!result.success) {
        updatedList.add(jsonStr);
        continue;
      }

      map['progress'] = result.progress;

      if (result.isDone) {
        final dir = await getApplicationDocumentsDirectory();
        final videosDir = Directory('${dir.path}/videos');
        if (!await videosDir.exists()) await videosDir.create(recursive: true);
        final savePath = '${videosDir.path}/${videoId}_dubbed.mp4';

        final dlResult = await ApiService.instance.downloadVideo(
          videoId: videoId,
          userId: userId,
          savePath: savePath,
        );

        if (dlResult.success) {
          map['status'] = 'done';
          map['dubbedPath'] = savePath;
          map['progress'] = 100;
          await _showNotification(name, success: true);
          changed = true;
        } else {
          map['status'] = 'failed';
          await _showNotification(name, success: false);
          changed = true;
        }
      } else if (result.isFailed) {
        map['status'] = 'failed';
        await _showNotification(name, success: false);
        changed = true;
      } else if (result.progress != (map['progress'] as int? ?? 0)) {
        changed = true;
      }

      updatedList.add(jsonEncode(map));
    } catch (_) {
      updatedList.add(jsonStr);
    }
  }

  if (changed) {
    await prefs.setStringList(_storageKey, updatedList);
  }
}

Future<void> _showNotification(String videoName, {required bool success}) async {
  final prefs = await SharedPreferences.getInstance();
  final enabled = prefs.getBool('notifications_enabled') ?? true;
  if (!enabled) return;

  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));

  const channel = AndroidNotificationDetails(
    'videodub_channel',
    'VideoDub',
    channelDescription: 'Notifications when your dubbed video is ready',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );

  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    success ? 'Video ready' : 'Processing failed',
    success
        ? '"$videoName" has been dubbed and is ready to watch.'
        : '"$videoName" could not be processed. Please try again.',
    const NotificationDetails(android: channel),
  );
}

class BackgroundWorker {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static Future<void> registerPolling() async {
    await Workmanager().registerPeriodicTask(
      _taskName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  static Future<void> cancelPolling() async {
    await Workmanager().cancelByUniqueName(_taskName);
  }
}