import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';

class NotificationService {
  // Lazily-initialized singleton to avoid static initialization order
  // problems and hot-reload related LateInitializationError.
  static NotificationService? _instance;
  factory NotificationService() =>
      _instance ??= NotificationService._internal();
  NotificationService._internal();

  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  FlutterLocalNotificationsPlugin get _notifications {
    _notificationsPlugin ??= FlutterLocalNotificationsPlugin();
    return _notificationsPlugin!;
  }

  /// Export diagnostic information to a timestamped text file and return the file path.
  /// This is intended as a temporary debugging aid when testing on devices.
  Future<String?> exportDiagnostics() async {
    try {
      await initialize();

      final buffer = StringBuffer();
      buffer.writeln('NotificationService Diagnostics');
      buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
      buffer.writeln('Platform supported: $_platformSupported');
      buffer.writeln('Initialized: $_initialized');

      // Timezone
      try {
        buffer.writeln('Timezone local: ${tz.local.name}');
      } catch (e) {
        buffer.writeln('Timezone local: <error: $e>');
      }

      // Permissions
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final notificationsPermission = await androidImpl
            ?.areNotificationsEnabled();
        buffer.writeln(
          'Android: areNotificationsEnabled: $notificationsPermission',
        );

        // Exact alarms permission can't always be queried on older plugin versions; note that we requested it
        buffer.writeln(
          'Android: requestedExactAlarmsPermission: true (request may have been made)',
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        // There's no direct sync method for granted here; rely on initialization logs
        buffer.writeln(
          'iOS/macOS: permissions requested on init (best-effort)',
        );
      }

      // Pending notifications
      final pending = await getPendingNotifications();
      buffer.writeln('Pending notifications count: ${pending.length}');
      for (final p in pending) {
        buffer.writeln('  ID:${p.id} Title:${p.title} Body:${p.body}');
      }

      // Write to a file in documents directory
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${dir.path}/notification_diagnostics_$timestamp.txt');
      await file.writeAsString(buffer.toString());

      debugPrint('[NotificationService] Diagnostics exported to ${file.path}');
      return file.path;
    } catch (e, st) {
      debugPrint('[NotificationService] exportDiagnostics failed: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Return diagnostic information as a string (no file I/O).
  Future<String> getDiagnosticsString() async {
    final buffer = StringBuffer();
    try {
      await initialize();

      buffer.writeln('NotificationService Diagnostics');
      buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
      buffer.writeln('Platform supported: $_platformSupported');
      buffer.writeln('Initialized: $_initialized');

      // Timezone
      try {
        buffer.writeln('Timezone local: ${tz.local.name}');
      } catch (e) {
        buffer.writeln('Timezone local: <error: $e>');
      }

      // Permissions
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidImpl = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final notificationsPermission = await androidImpl
            ?.areNotificationsEnabled();
        buffer.writeln(
          'Android: areNotificationsEnabled: $notificationsPermission',
        );
        buffer.writeln(
          'Android: requestedExactAlarmsPermission: true (request may have been made)',
        );
      } else if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        buffer.writeln(
          'iOS/macOS: permissions requested on init (best-effort)',
        );
      }

      final pending = await getPendingNotifications();
      buffer.writeln('Pending notifications count: ${pending.length}');
      for (final p in pending) {
        buffer.writeln('  ID:${p.id} Title:${p.title} Body:${p.body}');
      }
    } catch (e, st) {
      buffer.writeln('Diagnostics generation failed: $e');
      buffer.writeln('$st');
    }

    return buffer.toString();
  }

  bool _initialized = false;
  bool _platformSupported = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Check if platform supports notifications
    _platformSupported = _isPlatformSupported();
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Notifications not supported on this platform',
      );
      _initialized = true; // Mark as initialized to avoid retries
      return;
    }

    // Initialize timezone database
    tz.initializeTimeZones();

    // Get the device's actual timezone
    try {
      final timeZoneName =
          (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint(
        '[NotificationService] Timezone set to device timezone: $timeZoneName',
      );
    } catch (e, st) {
      debugPrint('[NotificationService] Failed to get device timezone: $e');
      debugPrint('$st');
      // Fallback to UTC if timezone detection fails
      debugPrint('[NotificationService] Falling back to UTC timezone');
    }

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS/macOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    // Create plugin instance here (avoid creating it earlier)
    _notificationsPlugin ??= FlutterLocalNotificationsPlugin();

    // Initialize with callback for when notification is tapped
    // The platform interface may not be registered immediately on some platforms
    // (especially desktop). Retry a few times if we hit a LateInitializationError
    int _initRetries = 0;
    const int _maxInitRetries = 6;
    while (true) {
      try {
        await _notificationsPlugin!.initialize(
          initSettings,
          onDidReceiveNotificationResponse: _onNotificationTapped,
        );
        break; // success
      } catch (e, st) {
        final typeName = e.runtimeType.toString();
        if (typeName == 'LateInitializationError' &&
            _initRetries < _maxInitRetries) {
          _initRetries++;
          debugPrint(
            '[NotificationService] Plugin not ready, retrying initialize ($_initRetries)',
          );
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        // If it's not a LateInitializationError or we've exhausted retries, log and rethrow
        debugPrint('[NotificationService] initialize failed: $e');
        debugPrint('$st');
        rethrow;
      }
    }

    _initialized = true;
    debugPrint('[NotificationService] Initialized successfully');
  }

  /// Check if the current platform supports notifications
  bool _isPlatformSupported() {
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    // Windows is not supported for scheduled notifications
  }

  /// Request notification permissions (especially important for iOS and Android 13+)
  Future<bool> requestPermissions() async {
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Notification permissions not supported on this platform',
      );
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      final granted = await _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Request notification permission for Android 13+
      final granted = await androidImplementation
          ?.requestNotificationsPermission();

      // Also request exact alarm permission for Android 12+
      // This will open system settings page where user must manually enable
      final exactAlarmGranted = await androidImplementation
          ?.requestExactAlarmsPermission();
      debugPrint(
        '[NotificationService] Exact alarms permission request result: $exactAlarmGranted',
      );

      return (granted ?? true);
    }
    return true;
  }

  /// Check if exact alarm permission is granted (Android 12+)
  Future<bool> canScheduleExactAlarms() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final canSchedule =
          await androidImplementation?.canScheduleExactNotifications() ?? false;
      debugPrint(
        '[NotificationService] Can schedule exact alarms: $canSchedule',
      );
      return canSchedule;
    }
    return true; // iOS and other platforms don't have this restriction
  }

  /// Check if app has notification permission
  Future<bool> areNotificationsEnabled() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final enabled =
          await androidImplementation?.areNotificationsEnabled() ?? false;
      debugPrint('[NotificationService] Notifications enabled: $enabled');
      return enabled;
    }
    return true; // Assume enabled for other platforms
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint(
      '[NotificationService] Notification tapped: ${response.payload}',
    );
    // TODO: Navigate to quiz screen or specific quiz set
    // You can add navigation logic here
  }

  /// Schedule a daily reminder at a specific time
  Future<void> scheduleDailyReminder({
    required String time, // Format: "HH:mm" (24-hour)
    String title = 'Time to practice!',
    String body = 'Don\'t forget to practice your quiz questions today.',
  }) async {
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Daily reminders not supported on this platform',
      );
      return;
    }

    await initialize();

    // Parse time string
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Create a TZDateTime for today at the specified time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the scheduled time is in the past today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint(
      '[NotificationService] Scheduling daily reminder at $scheduledDate',
    );

    // Android notification details
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder',
      'Daily Reminders',
      channelDescription: 'Daily quiz practice reminders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    // iOS notification details
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // Schedule daily repeating notification
    // Plugin must be initialized by this point (initialize() was awaited above)
    const dailyNotificationId = 100;
    await _notificationsPlugin!.zonedSchedule(
      dailyNotificationId, // Notification ID
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents:
          DateTimeComponents.time, // Repeat daily at same time
    );

    debugPrint(
      '[NotificationService] Daily reminder scheduled successfully (id: $dailyNotificationId)',
    );
    // Debug: list pending notifications after scheduling
    try {
      final pendingAfter = await getPendingNotifications();
      debugPrint(
        '[NotificationService] Pending after scheduleDailyReminder: ${pendingAfter.length}',
      );
    } catch (e, st) {
      debugPrint(
        '[NotificationService] Pending check after daily schedule failed: $e',
      );
      debugPrint('$st');
    }
  }

  /// Schedule a weekly reminder
  Future<void> scheduleWeeklyReminder({
    required String time, // Format: "HH:mm"
    required int dayOfWeek, // 1 = Monday, 7 = Sunday
    String title = 'Time to practice!',
    String body = 'Don\'t forget to practice your quiz questions this week.',
  }) async {
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Weekly reminders not supported on this platform',
      );
      return;
    }

    await initialize();

    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    final now = tz.TZDateTime.now(tz.local);

    // Find next occurrence of the specified day
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Adjust to the next occurrence of dayOfWeek
    while (scheduledDate.weekday != dayOfWeek || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('[NotificationService] Current time: $now');
    debugPrint(
      '[NotificationService] Scheduling weekly reminder for day $dayOfWeek at $scheduledDate',
    );
    debugPrint(
      '[NotificationService] Time until notification: ${scheduledDate.difference(now)}',
    );

    const androidDetails = AndroidNotificationDetails(
      'weekly_reminder',
      'Weekly Reminders',
      channelDescription: 'Weekly quiz practice reminders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    try {
      final weeklyId = 200 + dayOfWeek; // IDs 201-207 for each day
      await _notifications.zonedSchedule(
        weeklyId,
        title,
        body,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
      debugPrint(
        '[NotificationService] Weekly reminder scheduled successfully for ID $weeklyId',
      );
      // Debug: list pending notifications after scheduling weekly reminder
      try {
        final pendingAfter = await getPendingNotifications();
        debugPrint(
          '[NotificationService] Pending after scheduleWeeklyReminder (day $dayOfWeek, id $weeklyId): ${pendingAfter.length}',
        );
      } catch (e, st) {
        debugPrint(
          '[NotificationService] Pending check after weekly schedule failed: $e',
        );
        debugPrint('$st');
      }
    } catch (e, st) {
      debugPrint(
        '[NotificationService] Failed to schedule weekly reminder: $e',
      );
      debugPrint('$st');
    }
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Cancel notifications not supported on this platform',
      );
      return;
    }

    if (!_initialized || _notificationsPlugin == null) {
      debugPrint(
        '[NotificationService] cancelAllNotifications called before initialization; nothing to cancel',
      );
      return;
    }

    // Retry if the platform interface isn't registered yet (LateInitializationError)
    int attempts = 0;
    const int maxAttempts = 6;
    while (true) {
      try {
        // Cancel daily reminder (ID 0) and all weekly reminders (IDs 11-17)
        await _notificationsPlugin!.cancel(100); // Daily
        for (int day = 1; day <= 7; day++) {
          await _notificationsPlugin!.cancel(
            200 + day,
          ); // Weekly for each day (201-207)
        }
        debugPrint('[NotificationService] All notifications cancelled');
        return;
      } catch (e, st) {
        final typeName = e.runtimeType.toString();
        final msg = e.toString();
        if ((typeName == 'LateInitializationError' ||
                msg.contains('_instance')) &&
            attempts < maxAttempts) {
          attempts++;
          debugPrint(
            '[NotificationService] cancelAllNotifications: platform not ready, retrying ($attempts)',
          );
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        debugPrint('[NotificationService] cancelAllNotifications failed: $e');
        debugPrint('$st');
        return; // don't rethrow during startup
      }
    }
  }

  /// Cancel a specific notification by ID
  Future<void> cancelNotification(int id) async {
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Cancel notifications not supported on this platform',
      );
      return;
    }

    if (!_initialized || _notificationsPlugin == null) {
      debugPrint(
        '[NotificationService] cancelNotification($id) called before initialization; nothing to cancel',
      );
      return;
    }

    int attempts = 0;
    const int maxAttempts = 6;
    while (true) {
      try {
        await _notificationsPlugin!.cancel(id);
        debugPrint('[NotificationService] Notification $id cancelled');
        return;
      } catch (e, st) {
        final typeName = e.runtimeType.toString();
        final msg = e.toString();
        if ((typeName == 'LateInitializationError' ||
                msg.contains('_instance')) &&
            attempts < maxAttempts) {
          attempts++;
          debugPrint(
            '[NotificationService] cancelNotification: platform not ready, retrying ($attempts)',
          );
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        debugPrint('[NotificationService] cancelNotification($id) failed: $e');
        debugPrint('$st');
        return;
      }
    }
  }

  /// Show an immediate notification (for testing)
  Future<void> showImmediateNotification({
    String title = 'Test Notification',
    String body = 'This is a test notification',
  }) async {
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Immediate notifications not supported on this platform',
      );
      return;
    }

    await initialize();

    const androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'Test notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    try {
      final androidImpl = _notificationsPlugin
          ?.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final areEnabled = await androidImpl?.areNotificationsEnabled();
      debugPrint('[NotificationService] areNotificationsEnabled: $areEnabled');

      await _notificationsPlugin!.show(999, title, body, details);
      debugPrint('[NotificationService] Immediate notification shown');

      // Debug: list pending notifications after showing
      final pending = await getPendingNotifications();
      debugPrint('[NotificationService] Pending after show: ${pending.length}');
    } catch (e, st) {
      debugPrint('[NotificationService] showImmediateNotification failed: $e');
      debugPrint('$st');
    }
  }

  /// Schedule a test notification in 1 minute (for debugging)
  Future<void> scheduleTestNotification() async {
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Test notifications not supported on this platform',
      );
      return;
    }

    await initialize();

    final now = tz.TZDateTime.now(tz.local);
    final testTime = now.add(const Duration(minutes: 1));

    debugPrint(
      '[NotificationService] Scheduling test notification at $testTime (in 1 minute)',
    );

    const androidDetails = AndroidNotificationDetails(
      'test_reminder',
      'Test Reminders',
      channelDescription: 'Test scheduled reminders',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    try {
      final androidImpl = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final areEnabled = await androidImpl?.areNotificationsEnabled();
      debugPrint(
        '[NotificationService] areNotificationsEnabled (scheduling): $areEnabled',
      );

      await _notifications.zonedSchedule(
        999, // Test notification ID
        'Test Scheduled Reminder',
        'This is a test of scheduled notifications. If you see this, scheduling works!',
        testTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
        '[NotificationService] Test notification scheduled successfully',
      );
      final pending = await getPendingNotifications();
      debugPrint(
        '[NotificationService] Pending after scheduleTest: ${pending.length}',
      );
    } catch (e, st) {
      debugPrint(
        '[NotificationService] Failed to schedule test notification: $e',
      );
      debugPrint('$st');
    }
  }

  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_platformSupported) {
      debugPrint(
        '[NotificationService] Pending notifications not supported on this platform',
      );
      return <PendingNotificationRequest>[];
    }

    if (!_initialized || _notificationsPlugin == null) {
      debugPrint(
        '[NotificationService] getPendingNotifications called before initialization; returning empty list',
      );
      return <PendingNotificationRequest>[];
    }

    int attempts = 0;
    const int maxAttempts = 6;
    while (true) {
      try {
        final pending = await _notificationsPlugin!
            .pendingNotificationRequests();
        debugPrint(
          '[NotificationService] Pending notifications: ${pending.length}',
        );
        for (final notification in pending) {
          debugPrint('  ID: ${notification.id}, Title: ${notification.title}');
        }
        return pending;
      } catch (e, st) {
        final typeName = e.runtimeType.toString();
        final msg = e.toString();
        if ((typeName == 'LateInitializationError' ||
                msg.contains('_instance')) &&
            attempts < maxAttempts) {
          attempts++;
          debugPrint(
            '[NotificationService] getPendingNotifications: platform not ready, retrying ($attempts)',
          );
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        debugPrint('[NotificationService] getPendingNotifications failed: $e');
        debugPrint('$st');
        return <PendingNotificationRequest>[];
      }
    }
  }

  /// Update scheduled notifications based on user preferences
  Future<void> updateFromPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? false;
    final time = prefs.getString('notification_time') ?? '09:00';
    final daysString = prefs.getString('notification_days') ?? 'monday';

    if (!enabled) {
      await cancelAllNotifications();
      return;
    }

    // Cancel existing and reschedule with new settings
    await cancelAllNotifications();

    final selectedDays = daysString
        .split(',')
        .where((day) => day.isNotEmpty)
        .toList();
    if (selectedDays.isEmpty) return;

    // If all 7 days are selected, use daily reminder (more efficient - only 1 notification)
    if (selectedDays.length == 7) {
      debugPrint(
        '[NotificationService] All days selected, using daily reminder',
      );
      await scheduleDailyReminder(time: time);
    } else {
      // Schedule separate weekly reminder for each selected day
      debugPrint(
        '[NotificationService] Scheduling ${selectedDays.length} weekly reminders',
      );
      for (final day in selectedDays) {
        final dayOfWeek = _getDayOfWeekFromString(day);
        if (dayOfWeek != null) {
          await scheduleWeeklyReminder(time: time, dayOfWeek: dayOfWeek);
        }
      }
    }

    // Debug: check pending after all scheduling
    try {
      final pendingAfterAll = await getPendingNotifications();
      debugPrint(
        '[NotificationService] Pending after updateFromPreferences: ${pendingAfterAll.length}',
      );
    } catch (e, st) {
      debugPrint(
        '[NotificationService] Pending check after updateFromPreferences failed: $e',
      );
      debugPrint('$st');
    }
  }

  int? _getDayOfWeekFromString(String day) {
    switch (day.toLowerCase()) {
      case 'monday':
        return 1;
      case 'tuesday':
        return 2;
      case 'wednesday':
        return 3;
      case 'thursday':
        return 4;
      case 'friday':
        return 5;
      case 'saturday':
        return 6;
      case 'sunday':
        return 7;
      default:
        return null;
    }
  }
}
