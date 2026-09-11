# Notification System Testing Guide

## Quick Start Testing (5 minutes)

### Step 1: Install & Launch App
```bash
flutter run --release
# Or install APK on physical device
```

### Step 2: Enable Reminders
1. Open app → Tap hamburger menu → **Settings**
2. Scroll to "Notifications" section
3. Toggle **"Enable Reminders"** ON
4. You'll see educational dialog → Tap **"Continue"**

### Step 3: Grant Permissions

**First Permission Dialog (Notifications):**
- System prompt: "Allow MCQ Quizzer to send you notifications?"
- Tap **"Allow"**

**Second Permission Dialog (Exact Alarms):**
- Educational dialog appears
- Tap **"Open Settings"**
- In system settings, find "Alarms & reminders"
- Toggle **ON**
- Press back button to return to app

### Step 4: Verify Setup
1. In Settings, tap **"Check Notification Status"**
2. Verify you see:
   ```
   ✅ Notifications Enabled
   ✅ Exact Alarms Permission Granted
   📅 Pending Reminders: [count]
   ```

### Step 5: Test Immediate Notification
1. In Settings, tap **"Test Notification"**
2. Notification should appear **immediately** at top of screen
3. Tap notification → app should open

### Step 6: Test Scheduled Notification
1. In Settings, scroll to "Reminder Time"
2. Set time to **1 minute from now**
3. Wait 1 minute
4. Notification should appear **exactly on time**

✅ **If all steps work, notifications are functioning correctly!**

---

## Troubleshooting Guide

### Problem: "Enable Reminders" toggle turns back off

**Cause:** Notification permission denied

**Fix:**
1. Open Android Settings
2. Apps → MCQ Quizzer → Notifications
3. Enable "Show notifications"
4. Return to app and try again

### Problem: "Exact Alarms" shows ❌ in status check

**Cause:** Alarms & reminders permission not granted

**Fix:**
1. Tap "Open Settings" in status dialog
2. Or manually: Android Settings → Apps → Special app access → Alarms & reminders
3. Find MCQ Quizzer → Enable
4. Return to app and check status again

### Problem: Test notification doesn't appear immediately

**Possible Causes:**
1. **Notifications disabled** → Check Android Settings → Apps → MCQ Quizzer → Notifications
2. **Do Not Disturb enabled** → Disable DND or add app to exceptions
3. **Battery saver active** → Disable or whitelist app
4. **App backgrounded** → Notifications should still show, check notification shade

**Debug Steps:**
```dart
// Check app logs
adb logcat | grep NotificationService
// Look for:
// - "areNotificationsEnabled: false" → Permissions issue
// - "Immediate notification shown" → Plugin working
```

### Problem: Scheduled notification doesn't fire at set time

**Possible Causes:**
1. **Exact alarm permission denied** → Check "Alarms & reminders" in system settings
2. **Device manufacturer restrictions** → See manufacturer-specific fixes below
3. **Battery optimization** → Whitelist app from battery optimization
4. **App force-stopped** → Some devices kill apps aggressively

**Debug Steps:**
1. Check pending notifications:
   ```
   Settings → Check Notification Status → See "Pending Reminders" count
   ```
2. If count is 0 → Notification wasn't scheduled (permission issue)
3. If count > 0 but not firing → Device restriction (see below)

### Problem: Notifications stop after device reboot

**Cause:** Boot receiver not working

**Fix:**
1. Check AndroidManifest.xml has:
   ```xml
   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
   <receiver android:name="...ScheduledNotificationBootReceiver" ...>
   ```
2. Some manufacturers require "Autostart" permission:
   - Xiaomi: Security → Autostart → Enable for MCQ Quizzer
   - Huawei: Settings → Battery → App launch → Enable for MCQ Quizzer

---

## Manufacturer-Specific Fixes

### Xiaomi / Redmi (MIUI)

**Problem:** Notifications don't fire when app is closed

**Fix:**
1. **Autostart:** Settings → Apps → Manage apps → MCQ Quizzer → Autostart → Enable
2. **Battery Saver:** Settings → Battery & performance → App battery saver → MCQ Quizzer → No restrictions
3. **Lock Screen Clean:** Security → Lock screen cleanup → Uncheck MCQ Quizzer
4. **Memory Optimization:** Recent apps → Lock MCQ Quizzer

### Huawei (EMUI)

**Problem:** App killed in background, notifications stop

**Fix:**
1. **Protected Apps:** Settings → Battery → App launch → MCQ Quizzer → Manage manually → Enable all
2. **Ignore Battery Optimization:** Settings → Battery → App launch → MCQ Quizzer → No restrictions
3. **Keep Running:** Settings → Apps → MCQ Quizzer → Battery → App launch → Manual → Enable all

### OnePlus (OxygenOS)

**Problem:** Notifications delayed or not showing

**Fix:**
1. **Battery Optimization:** Settings → Battery → Battery optimization → MCQ Quizzer → Don't optimize
2. **App Auto Launch:** Settings → Battery → Battery optimization → Advanced optimization → Deep optimization → Disable for MCQ Quizzer

### Samsung (One UI)

**Problem:** Notifications work initially then stop

**Fix:**
1. **Sleeping Apps:** Settings → Battery → Background usage limits → Remove MCQ Quizzer from sleeping apps
2. **Adaptive Battery:** Settings → Battery → More battery settings → Adaptive battery → Add exception for MCQ Quizzer
3. **Deep Sleep:** Settings → Device care → Battery → App power management → Apps that won't be put to sleep → Add MCQ Quizzer

### Oppo / Realme (ColorOS)

**Problem:** Notifications don't survive app closure

**Fix:**
1. **Startup Manager:** Settings → Privacy → Permission manager → Startup manager → Enable for MCQ Quizzer
2. **Background Apps:** Settings → Battery → Power-intensive prompt → Turn off for MCQ Quizzer
3. **App Lock:** Recent apps → Lock MCQ Quizzer

---

## Advanced Testing

### Test 1: Daily Reminder
```
1. Set reminder time to tomorrow at 9:00 AM
2. Check pending notifications: should show "ID: 100"
3. Wait until next day at 9:00 AM
4. Notification should fire exactly at 9:00 AM
5. Check again next day - should fire again (daily repeat)
```

### Test 2: Weekly Reminder
```
1. Select Monday, Wednesday, Friday
2. Set time to 10:00 AM
3. Check pending: should show 3 notifications (IDs: 201, 203, 205)
4. On Monday at 10:00 AM - notification fires
5. Tuesday - no notification
6. Wednesday at 10:00 AM - notification fires
```

### Test 3: Notification After Reboot
```
1. Schedule notification for 2 hours from now
2. Check pending: should show 1 notification
3. Reboot device
4. After reboot, check pending: should STILL show 1 notification
5. Wait for scheduled time - notification should fire
```

### Test 4: Permission Revocation
```
1. Schedule notification
2. Go to Android Settings → Apps → Special app access → Alarms & reminders
3. Disable for MCQ Quizzer
4. Return to app → Try to schedule another notification
5. Should show warning dialog
6. Check pending: old notification should be cancelled
```

### Test 5: Do Not Disturb Mode
```
1. Schedule notification for 2 minutes from now
2. Enable Do Not Disturb on device
3. Wait for notification time
4. Notification should still fire (may be silent depending on DND settings)
5. Check notification shade - notification should be visible
```

### Test 6: Battery Saver Mode
```
1. Schedule notification for 5 minutes from now
2. Enable Battery Saver mode
3. Lock device and leave it idle
4. At scheduled time, device should wake and show notification
5. This tests exactAllowWhileIdle mode
```

---

## ADB Commands for Testing

### Check Notification Permission
```bash
adb shell dumpsys notification | grep "MCQ Quizzer"
```

### Check Alarms
```bash
adb shell dumpsys alarm | grep "mcq_quizzer"
```

### Check Pending Notifications
```bash
adb shell dumpsys notification --noredact | grep -A 20 "mcq_quizzer"
```

### Grant Permission Manually
```bash
# Grant notification permission
adb shell pm grant com.yourcompany.mcq_quizzer android.permission.POST_NOTIFICATIONS

# Cannot grant SCHEDULE_EXACT_ALARM via ADB - must do manually in UI
```

### Test Notification Manually
```bash
# Send test notification via ADB
adb shell am broadcast -a com.yourcompany.mcq_quizzer.TEST_NOTIFICATION
```

### Clear App Data (Reset)
```bash
adb shell pm clear com.yourcompany.mcq_quizzer
```

---

## Expected Log Output

### Successful Initialization
```
[NotificationService] Timezone set from tz.local: America/New_York
[NotificationService] Initialized successfully
[NotificationService] areNotificationsEnabled: true
[NotificationService] Can schedule exact alarms: true
```

### Successful Scheduling
```
[NotificationService] Scheduling daily reminder at 2025-11-06 09:00:00.000
[NotificationService] Daily reminder scheduled successfully (id: 100)
[NotificationService] Pending after scheduleDailyReminder: 1
```

### Permission Issues
```
[NotificationService] areNotificationsEnabled: false
[NotificationService] Can schedule exact alarms: false
⚠️ User needs to grant permissions
```

### Scheduling Failure
```
[NotificationService] Failed to schedule daily reminder: PlatformException(...)
❌ Check exact alarm permission
```

---

## Success Criteria

✅ **Minimum Viable:**
- Test notification appears immediately
- Scheduled test (1 minute) fires exactly on time
- Status check shows all green checkmarks
- Notifications persist after app closure

✅ **Full Functionality:**
- Daily reminders fire at set time every day
- Weekly reminders fire on correct days only
- Notifications survive device reboot
- Multiple reminders can coexist
- Cancellation works correctly

✅ **Edge Cases:**
- Works with Do Not Disturb enabled
- Works with battery saver enabled
- Works after permission revocation → re-grant
- Works on manufacturer-specific ROMs (Xiaomi, Huawei, etc.)

---

## Support Resources

- **Official Android Docs:** https://developer.android.com/training/scheduling/alarms
- **Plugin Documentation:** https://pub.dev/packages/flutter_local_notifications
- **Manufacturer Restrictions:** https://dontkillmyapp.com/
- **Stack Overflow Tag:** `flutter-local-notifications`

---

## Report Template

When reporting issues, please include:

```
**Device Information:**
- Manufacturer: [e.g., Samsung]
- Model: [e.g., Galaxy S23]
- Android Version: [e.g., 13]
- ROM: [e.g., One UI 5.1]

**App Version:**
- MCQ Quizzer version: [e.g., 1.0.0]
- flutter_local_notifications: 19.5.0

**Steps Taken:**
1. [What you did]
2. [What you expected]
3. [What actually happened]

**Permissions Status:**
- Notifications Enabled: [Yes/No]
- Exact Alarms Granted: [Yes/No]
- Battery Optimization: [Enabled/Disabled]

**Logs:**
[Paste relevant logs from logcat]
```

---

Last Updated: November 5, 2025
