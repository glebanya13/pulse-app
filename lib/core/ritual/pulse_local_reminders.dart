import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// City-aware local reminders: Friday digest + optional daily 19:00.
class PulseLocalReminders {
  PulseLocalReminders._();

  static const prefsEnabledKey = 'pulse_friday_reminder_enabled';
  static const prefsCityNameKey = 'pulse_reminder_city_name';
  static const fridayNotificationId = 91001;
  static const dailyNotificationId = 91002;
  static const todayLocation = '/home/events?tab=today';

  /// Kept for callers that still reference the old id.
  static const notificationId = fridayNotificationId;

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static void Function(String location)? _onOpen;

  static void attachOpenHandler(void Function(String location) handler) {
    _onOpen = handler;
  }

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    try {
      tzdata.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Minsk'));
      } catch (_) {
        // Fall back to device local if zone DB lacks Minsk.
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        settings: const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _onOpen?.call(payload);
          }
        },
      );

      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        final payload = launch!.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          Future<void>.delayed(const Duration(milliseconds: 500), () {
            _onOpen?.call(payload);
          });
        }
      }

      _initialized = true;

      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(prefsEnabledKey) ?? true;
      if (enabled) {
        await enable();
      }
    } catch (e, st) {
      debugPrint('PulseLocalReminders init skipped: $e\n$st');
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsEnabledKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefsEnabledKey, enabled);
    if (enabled) {
      await enable();
    } else {
      await disable();
    }
  }

  /// Update city label and reschedule if reminders are on.
  static Future<void> rescheduleForCity(String cityName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefsCityNameKey, cityName);
    final enabled = prefs.getBool(prefsEnabledKey) ?? true;
    if (enabled) {
      await enable();
    }
  }

  static Future<String> _cityName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefsCityNameKey) ?? 'Минск';
  }

  static Future<void> enable() async {
    if (!_initialized) await init();
    if (!_initialized) return;

    final granted = await _requestPermission();
    if (!granted) return;

    await _plugin.cancel(id: fridayNotificationId);
    await _plugin.cancel(id: dailyNotificationId);

    final city = await _cityName();

    const androidDetails = AndroidNotificationDetails(
      'pulse_afisha',
      'Афиша',
      channelDescription: 'Напоминания о вечерах в вашем городе',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final friday = _nextFridayAt(18, 0);
    await _plugin.zonedSchedule(
      id: fridayNotificationId,
      title: 'Что сегодня · $city?',
      body: 'Откройте афишу Пульса - клубы, концерты и вечеринки на сегодня',
      scheduledDate: friday,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: todayLocation,
    );

    final daily = _nextDailyAt(19, 0);
    await _plugin.zonedSchedule(
      id: dailyNotificationId,
      title: 'Вечер · $city',
      body: 'Загляните в афишу Пульса - что интересного сегодня',
      scheduledDate: daily,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: todayLocation,
    );
    debugPrint('PulseLocalReminders scheduled friday=$friday daily=$daily city=$city');
  }

  static Future<void> disable() async {
    if (!_initialized) return;
    await _plugin.cancel(id: fridayNotificationId);
    await _plugin.cancel(id: dailyNotificationId);
  }

  static Future<bool> _requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  /// Next Friday 18:00 Europe/Minsk (or local).
  static tz.TZDateTime _nextFridayAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (scheduled.weekday != DateTime.friday || !scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      scheduled = tz.TZDateTime(
        tz.local,
        scheduled.year,
        scheduled.month,
        scheduled.day,
        hour,
        minute,
      );
    }
    return scheduled;
  }

  static tz.TZDateTime _nextDailyAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      scheduled = tz.TZDateTime(
        tz.local,
        scheduled.year,
        scheduled.month,
        scheduled.day,
        hour,
        minute,
      );
    }
    return scheduled;
  }
}
