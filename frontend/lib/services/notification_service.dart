import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Cross-platform local notification service.
/// Supports Android, iOS, macOS, Linux, and Windows desktop.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Android notification channel ──────────────────────────────────────────
  static const _androidChannel = AndroidNotificationChannel(
    'padma_chat_channel',
    'Chat Messages',
    description: 'New family chat messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // ── Android ─────────────────────────────────────────────────────────
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // ── iOS / macOS ──────────────────────────────────────────────────────
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // ── Linux ────────────────────────────────────────────────────────────
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );

      // ── Windows ──────────────────────────────────────────────────────────
      // WindowsInitializationSettings requires a valid GUID and app name.
      // The GUID should be unique per app but can be any valid UUID.
      const windowsSettings = WindowsInitializationSettings(
        appName: 'Padma Mangal',
        appUserModelId: 'com.padmamangal.app',
        guid: '4c5d6f78-a1b2-4c3d-8e9f-0a1b2c3d4e5f',
      );

      final initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: !kIsWeb && Platform.isLinux ? linuxSettings : null,
        windows: !kIsWeb && Platform.isWindows ? windowsSettings : null,
      );

      await _plugin.initialize(initSettings);

      // ── Android: create channel & request permission ────────────────────
      if (!kIsWeb && Platform.isAndroid) {
        final androidImpl = _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidImpl != null) {
          await androidImpl.createNotificationChannel(_androidChannel);
          await androidImpl.requestNotificationsPermission();
        }
      }

      // ── iOS: request permission ─────────────────────────────────────────
      if (!kIsWeb && Platform.isIOS) {
        final iosImpl = _plugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        await iosImpl?.requestPermissions(
            alert: true, badge: true, sound: true);
      }

      // ── macOS: request permission ───────────────────────────────────────
      if (!kIsWeb && Platform.isMacOS) {
        final macImpl = _plugin
            .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin>();
        await macImpl?.requestPermissions(
            alert: true, badge: true, sound: true);
      }

      _initialized = true;
      debugPrint('[Notifications] Initialized on ${_platformName()}');
    } catch (e) {
      debugPrint('[Notifications] Init failed: $e');
      // Don't crash the app if notifications fail to initialize
    }
  }

  String _platformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }

  // ── Show a chat message notification ─────────────────────────────────────
  Future<void> showMessageNotification({
    required String senderName,
    required String messagePreview,
    int id = 1,
  }) async {
    if (!_initialized) {
      await initialize();
    }
    if (!_initialized) return; // Still failed — silently skip

    final preview = messagePreview.isEmpty
        ? '📎 Sent an attachment'
        : messagePreview.length > 80
            ? '${messagePreview.substring(0, 80)}…'
            : messagePreview;

    try {
      const androidDetails = AndroidNotificationDetails(
        'padma_chat_channel',
        'Chat Messages',
        channelDescription: 'New family chat messages',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        ticker: 'New message',
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const linuxDetails = LinuxNotificationDetails();

      const windowsDetails = WindowsNotificationDetails();

      final details = NotificationDetails(
        android: !kIsWeb && Platform.isAndroid ? androidDetails : null,
        iOS: !kIsWeb && Platform.isIOS ? darwinDetails : null,
        macOS: !kIsWeb && Platform.isMacOS ? darwinDetails : null,
        linux: !kIsWeb && Platform.isLinux ? linuxDetails : null,
        windows: !kIsWeb && Platform.isWindows ? windowsDetails : null,
      );

      await _plugin.show(id, senderName, preview, details);
      debugPrint('[Notifications] Shown: "$senderName: $preview"');
    } catch (e) {
      debugPrint('[Notifications] Show failed: $e');
    }
  }
}
