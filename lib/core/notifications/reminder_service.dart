import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/tracker/domain/reminder_rules.dart';

/// Schedules the reminders the rules produce. Everything fails quietly: a device that cannot show notifications
/// should never break the tracker.
class ReminderService {
  ReminderService._();
  static final instance = ReminderService._();

  static const _channelId = 'reminders';

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  var _askedThisSession = false;

  /// Set by the app: called with the payload of a tapped notification.
  void Function(String payload)? onTap;
  String? _launchPayload;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
        onDidReceiveNotificationResponse: (r) {
          final payload = r.payload;
          if (payload != null) onTap?.call(payload);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) _launchPayload = launch!.notificationResponse?.payload;
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  /// The notification that opened the app from closed, once.
  String? takeLaunchPayload() {
    final p = _launchPayload;
    _launchPayload = null;
    return p;
  }

  Future<bool> get allowed async {
    if (!_ready) return false;
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Asks for permission at the moment a reminder first matters, not at launch. Android shows its own dialog.
  Future<bool> ensurePermission() async {
    if (!_ready) return false;
    if (await allowed) return true;
    if (_askedThisSession) return false;
    _askedThisSession = true;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Replaces every scheduled reminder with [reminders]. Cancelling everything first keeps this idempotent.
  Future<void> sync(List<Reminder> reminders) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      // Exact alarms need a permission the user can refuse; without it the system may deliver a little late.
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
      for (final r in reminders) {
        await _plugin.zonedSchedule(
          id: r.id,
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              'Reminders',
              channelDescription: 'Follow-ups and interview warm-ups from your tracker',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: mode,
          payload: r.payload,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }
}
