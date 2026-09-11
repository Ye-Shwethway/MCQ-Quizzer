# Notification System Research & Fixes

## Date: November 5, 2025

## Official Documentation Review

### Sources Reviewed:
1. **flutter_local_notifications v19.5.0** - https://pub.dev/packages/flutter_local_notifications
2. **Android Alarms Documentation** - https://developer.android.com/training/scheduling/alarms
3. **Android Notification Permissions** - https://developer.android.com/develop/ui/views/notifications/notification-permission

---

## Key Findings from Official Docs

### 1. Plugin Version Issue ⚠️

**Problem:**
- Our app was using `flutter_local_notifications: ^17.0.0` (outdated)
- Latest stable version is **19.5.0** (published 18 days ago)
- Version 17 may have bugs with Android 12+ exact alarm handling

**Fix Applied:**
```yaml
# pubspec.yaml
flutter_local_notifications: ^19.5.0
timezone: ^0.10.1  # Also updated for compatibility
```

### 2. Android Exact Alarm Permissions 🔐

**Official Android Guidelines:**

Android 12+ requires one of two permissions for exact alarms:

| Permission | Grant Method | Use Case | Google Play Policy |
|------------|-------------|----------|-------------------|
| `SCHEDULE_EXACT_ALARM` | User must manually enable in system settings | User-facing alarms (quiz reminders, fitness tracking) | ✅ Allowed for broad use cases |
| `USE_EXACT_ALARM` | Auto-granted, cannot be revoked | Calendar apps, alarm clock apps only | ⚠️ Requires justification, subject to audit |

**Problem in Our Code:**
```xml
<!-- AndroidManifest.xml had BOTH permissions - causes conflicts -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.USE_EXACT_ALARM"/>  <!-- REMOVED ❌ -->
```

**Android docs explicitly state:** Apps should declare only ONE of these permissions, not both.

**Fix Applied:**
- Removed `USE_EXACT_ALARM` (only for calendar/alarm clock core functionality)
- Kept `SCHEDULE_EXACT_ALARM` (appropriate for quiz reminder feature)

### 3. Exact Alarm Permission Flow 🔄

**What Happens When User Denies Permission:**

From Android docs:
```
When SCHEDULE_EXACT_ALARM permission is revoked:
1. App is stopped immediately
2. All scheduled exact alarms are cancelled
3. canScheduleExactAlarms() returns false
4. Attempting to schedule exact alarm logs error but silently fails
```

**Our Implementation Status:**
- ✅ Check `canScheduleExactAlarms()` before scheduling
- ✅ Open system settings for manual permission grant
- ✅ Show educational dialogs explaining why permission needed
- ✅ Re-check permission status after user returns from settings
- ⚠️ Could add: Broadcast receiver for `ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED`

### 4. Scheduling Mode Best Practices 📅

**Android Scheduling Options:**

| Method | Timing Precision | Battery Impact | Use Case |
|--------|-----------------|----------------|----------|
| `set()` | ±1 hour | Low | Non-critical notifications |
| `setWindow()` | Within 10-min window | Low | Flexible timing |
| `setInexactRepeating()` | Batched with others | Very Low | Background sync |
| `setExact()` | Precise but deferred in Doze | Medium | Important reminders |
| `setExactAndAllowWhileIdle()` | **Precise, even in Doze** | High | **Quiz reminders (our choice)** ✅ |
| `setAlarmClock()` | Most precise, shows in status bar | Very High | Alarm clock apps only |

**Our Implementation:**
```dart
await _notifications.zonedSchedule(
  id,
  title,
  body,
  scheduledDate,
  details,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,  // ✅ Correct
  matchDateTimeComponents: DateTimeComponents.time,  // ✅ Correct for daily repeat
);
```

**Why This Is Correct:**
- `exactAllowWhileIdle` wakes device even in Doze mode
- Required for time-critical user-facing notifications
- Follows official recommendation for alarm-style reminders

### 5. Notification Permission (Android 13+) 🔔

**Android 13 Runtime Permission:**

```
POST_NOTIFICATIONS permission required for Android 13+
- Must request at runtime
- User can deny
- Can check with areNotificationsEnabled()
```

**Best Practices from Official Docs:**
1. ✅ Don't request on first app launch
2. ✅ Request in context (when user enables reminders)
3. ✅ Show educational dialog before request
4. ✅ Check permission status before showing notifications
5. ✅ Handle "Don't ask again" scenario

**Our Implementation:**
```dart
Future<bool> areNotificationsEnabled() async {
  final androidImpl = _notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  return await androidImpl?.areNotificationsEnabled() ?? false;
}
```

✅ **Status:** Fully implemented following official guidelines

---

## What We're Doing Right ✅

### 1. Modern Timezone-Based Scheduling
```dart
// ✅ Using zonedSchedule (recommended)
await _notifications.zonedSchedule(
  id,
  title,
  body,
  tz.TZDateTime.now(tz.local).add(duration),
  details,
  // ...
);

// ❌ Not using deprecated schedule()
```

**Why Correct:**
- Handles daylight saving time correctly
- Works across all timezones
- Follows plugin's latest recommendations

### 2. Permission Checking Before Actions
```dart
// ✅ Check before scheduling
final canSchedule = await canScheduleExactAlarms();
if (!canSchedule) {
  // Open system settings
  await androidImpl?.requestExactAlarmsPermission();
}
```

**Why Correct:**
- Prevents silent failures
- Provides user feedback
- Follows Android best practices

### 3. Educational User Experience
```dart
// ✅ Explain before requesting
await _showPermissionEducationDialog(
  icon: Icons.notifications_active,
  title: 'Enable Quiz Reminders',
  message: 'To send you quiz practice reminders at your chosen time, '
          'we need permission to schedule exact alarms.',
);
```

**Why Correct:**
- Increases permission grant rate
- Builds user trust
- Follows Material Design guidelines

### 4. Comprehensive Diagnostics
```dart
// ✅ Status checking dialog
await _showNotificationStatusDialog() {
  // Shows: Notifications enabled, Exact alarms permission, Pending reminders
}
```

**Why Correct:**
- Helps users troubleshoot
- Provides transparency
- Reduces support requests

---

## Potential Improvements 🚀

### 1. Permission State Change Listener (Optional)

**From Android Docs:**
```
When SCHEDULE_EXACT_ALARM permission state changes,
system sends ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED broadcast
```

**Could Add:**
```dart
// Listen for permission revocation and reschedule
class AlarmPermissionReceiver extends BroadcastReceiver {
  @override
  void onReceive(Context context, Intent intent) {
    if (canScheduleExactAlarms()) {
      // Permission granted - reschedule alarms
    } else {
      // Permission revoked - notify user
    }
  }
}
```

**Benefit:** Automatically handle permission changes without app restart

### 2. Fallback to Inexact Alarms (Optional)

**From Plugin Docs:**
```dart
// If exact permission denied, fall back to inexact
if (!canScheduleExactAlarms()) {
  androidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
  // Show warning to user that timing may vary ±1 hour
}
```

**Benefit:** Still provide some notification functionality even without exact alarms

### 3. Battery Optimization Check (Optional)

**Some manufacturers (Xiaomi, Huawei) have aggressive battery optimization:**
```dart
// Check if app is whitelisted from battery optimization
final isIgnoringBatteryOptimizations = 
    await permission_handler.Permission.ignoreBatteryOptimizations.isGranted;

if (!isIgnoringBatteryOptimizations) {
  // Show dialog explaining battery optimization impact
  // Offer to open settings
}
```

**Benefit:** Address manufacturer-specific restrictions (see dontkillmyapp.com)

---

## Testing Checklist ✓

### Before Device Testing:
- [x] Plugin updated to v19.5.0
- [x] Timezone updated to v0.10.1
- [x] Conflicting permission removed from manifest
- [x] Code compiles without errors
- [x] All permission checking methods implemented

### On Device Testing:
- [ ] Install app on Android 12+ device
- [ ] Enable reminders in settings
- [ ] Verify educational dialog appears
- [ ] Grant notification permission
- [ ] Tap "Open Settings" for exact alarms
- [ ] Grant "Alarms & reminders" permission in system settings
- [ ] Verify "Check Notification Status" shows all green checkmarks
- [ ] Tap "Test Notification" - should appear immediately
- [ ] Schedule test for 1 minute - should fire exactly on time
- [ ] Set daily reminder - verify it fires next day
- [ ] Set weekly reminder - verify it fires on correct day
- [ ] Reboot device - verify reminders persist
- [ ] Revoke exact alarm permission - verify app handles gracefully
- [ ] Re-enable permission - verify reminders reschedule

### Edge Cases:
- [ ] Test with Do Not Disturb mode enabled
- [ ] Test with battery saver mode enabled
- [ ] Test with airplane mode (should queue and fire when online)
- [ ] Test with multiple reminders scheduled
- [ ] Test cancelling specific reminder
- [ ] Test cancelling all reminders

---

## Why Notifications May Still Fail 🚨

### 1. OEM-Specific Restrictions

**Manufacturers with Known Issues:**
- **Xiaomi/Redmi:** MIUI has aggressive background restrictions
- **Huawei:** EMUI battery optimization kills background apps
- **OnePlus:** OxygenOS battery optimization
- **Samsung:** Adaptive Battery learning algorithm

**Solution:**
- Guide users to dontkillmyapp.com for device-specific instructions
- Add link in troubleshooting dialog

### 2. Battery Optimization

**Even with exact alarm permission:**
- Doze mode can delay notifications
- App standby buckets affect delivery
- Manufacturer-specific power saving modes

**Solution:**
- Request `ignoreBatteryOptimizations` permission
- Use `exactAllowWhileIdle` (already implemented ✅)

### 3. Android Restrictions

**From Android docs:**
- Samsung limit: 500 alarms per app maximum
- Pending notifications limit: 64 on iOS
- Some Android versions defer inexact alarms up to 15 minutes

**Solution:**
- Don't schedule more than 50-100 notifications
- Clean up old/cancelled notifications regularly

---

## Summary of Changes Made

### 1. pubspec.yaml
```diff
- flutter_local_notifications: ^17.0.0
+ flutter_local_notifications: ^19.5.0

- timezone: ^0.9.4
+ timezone: ^0.10.1
```

### 2. AndroidManifest.xml
```diff
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
- <uses-permission android:name="android.permission.USE_EXACT_ALARM"/>
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

### 3. Code (Already Implemented ✅)
- Permission checking methods
- Educational dialogs
- System settings navigation
- Status checking UI
- Test notification tools

---

## Official Documentation Links

1. **flutter_local_notifications Plugin:**
   - Main docs: https://pub.dev/packages/flutter_local_notifications
   - GitHub: https://github.com/MaikuB/flutter_local_notifications
   - API reference: https://pub.dev/documentation/flutter_local_notifications/latest/

2. **Android Alarms:**
   - Schedule alarms: https://developer.android.com/training/scheduling/alarms
   - Exact alarms policy: https://developer.android.com/about/versions/14/changes/schedule-exact-alarms
   - AlarmManager API: https://developer.android.com/reference/android/app/AlarmManager

3. **Android Notifications:**
   - Runtime permission: https://developer.android.com/develop/ui/views/notifications/notification-permission
   - Notification channels: https://developer.android.com/develop/ui/views/notifications/channels
   - Best practices: https://developer.android.com/develop/ui/views/notifications

4. **Device-Specific Issues:**
   - Don't Kill My App: https://dontkillmyapp.com/
   - Manufacturer restrictions database

---

## Next Steps

1. **Test on Physical Android Device (HIGH PRIORITY)**
   - Follow testing checklist above
   - Document any issues encountered
   - Note device model/Android version for debugging

2. **Monitor for Issues**
   - Check logs for any errors
   - Verify notifications fire at expected times
   - Gather user feedback after release

3. **Consider Optional Improvements**
   - Add permission state change listener
   - Implement fallback to inexact alarms
   - Add battery optimization check

4. **Update User Documentation**
   - Add FAQ about notification setup
   - Include device-specific troubleshooting
   - Link to dontkillmyapp.com

---

## Conclusion

Our notification implementation **follows official best practices** and uses the **correct modern APIs**. The main issues were:

1. ✅ **Fixed:** Outdated plugin version (17.0.0 → 19.5.0)
2. ✅ **Fixed:** Conflicting permissions in manifest (removed USE_EXACT_ALARM)
3. ✅ **Correct:** Using `exactAllowWhileIdle` for reliable delivery
4. ✅ **Correct:** Comprehensive permission checking and user guidance
5. ✅ **Correct:** Timezone-based scheduling with proper repeating

**The notification system should now work reliably on Android 12+ devices** when users grant the required permissions. Any remaining issues would likely be device-specific (OEM restrictions) rather than code problems.

