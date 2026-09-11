import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/quiz_service.dart';
import '../services/notification_service.dart';
import 'package:flutter/services.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late SharedPreferences _prefs;
  bool _isLoading = true;

  // Settings values
  ScoringMethod _defaultScoringMethod = ScoringMethod.straight;
  int _defaultTimerMinutes = 60;
  bool _enableTimerByDefault = false;
  bool _notificationsEnabled = false;
  String _notificationTime = '09:00';
  List<String> _selectedDays = [
    'monday',
  ]; // Default to Monday for backward compatibility

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();

    setState(() {
      // Load scoring method
      final scoringMethodName =
          _prefs.getString('default_scoring_method') ?? 'straight';
      _defaultScoringMethod = ScoringMethod.values.firstWhere(
        (m) => m.name == scoringMethodName,
        orElse: () => ScoringMethod.straight,
      );

      // Load timer settings
      _defaultTimerMinutes = _prefs.getInt('default_timer_minutes') ?? 60;
      _enableTimerByDefault =
          _prefs.getBool('enable_timer_by_default') ?? false;

      // Load notification settings
      _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? false;
      _notificationTime = _prefs.getString('notification_time') ?? '09:00';
      final daysString = _prefs.getString('notification_days');
      if (daysString != null && daysString.isNotEmpty) {
        _selectedDays = daysString.split(',');
      } else {
        // Backward compatibility: if old frequency was 'daily', select all days
        final oldFrequency =
            _prefs.getString('notification_frequency') ?? 'daily';
        if (oldFrequency == 'daily') {
          _selectedDays = [
            'monday',
            'tuesday',
            'wednesday',
            'thursday',
            'friday',
            'saturday',
            'sunday',
          ];
        } else {
          _selectedDays = ['monday']; // Default for weekly
        }
      }

      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    }
  }

  /// Check and request all necessary notification permissions (Android-specific)
  Future<bool> _checkAndRequestNotificationPermissions() async {
    final notificationService = NotificationService();

    // First check if notifications are enabled
    final notificationsEnabled = await notificationService
        .areNotificationsEnabled();
    if (!notificationsEnabled) {
      await _showPermissionEducationDialog(
        title: 'Enable Notifications',
        message:
            'To receive quiz reminders, please enable notifications for this app in system settings.',
        icon: Icons.notifications_off,
      );

      // Request permission
      final granted = await notificationService.requestPermissions();
      if (!granted) {
        return false;
      }
    }

    // Then check if exact alarms can be scheduled (Android 12+)
    final canScheduleExact = await notificationService.canScheduleExactAlarms();
    if (!canScheduleExact) {
      await _showPermissionEducationDialog(
        title: 'Enable Exact Alarms',
        message:
            'For reminders to work reliably, you need to enable "Alarms & reminders" permission.\n\n'
            'This will open system settings. Please:\n'
            '1. Find "MCQ Quizzer" in the list\n'
            '2. Enable "Alarms & reminders"\n'
            '3. Return to the app',
        icon: Icons.alarm,
      );

      // Request exact alarm permission (this opens system settings)
      await notificationService.requestPermissions();

      // Give user time to grant permission
      await Future.delayed(const Duration(seconds: 1));

      // Check again after user returns
      final canScheduleNow = await notificationService.canScheduleExactAlarms();
      if (!canScheduleNow && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '⚠️ Exact alarms not enabled. Reminders may not work reliably.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return canScheduleNow;
    }

    return true;
  }

  /// Show educational dialog explaining why permission is needed
  Future<void> _showPermissionEducationDialog({
    required String title,
    required String message,
    required IconData icon,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          icon,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data but keep your quiz sets and history.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Clear specific cache keys, not all preferences
      await _prefs.remove('cached_data');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache cleared successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return Scaffold(
        drawer: const AppDrawer(currentRoute: '/settings'),
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/settings'),
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Use dark theme'),
            secondary: Icon(
              themeProvider.themeMode == ThemeMode.dark
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            value: themeProvider.themeMode == ThemeMode.dark,
            onChanged: (value) {
              themeProvider.toggleTheme();
              _saveSetting('dark_mode', value);
            },
          ),
          const Divider(),

          // Quiz Defaults Section
          _buildSectionHeader('Quiz Defaults'),
          ListTile(
            leading: const Icon(Icons.assessment),
            title: const Text('Default Scoring Method'),
            subtitle: Text(_defaultScoringMethod.name.toUpperCase()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showScoringMethodDialog(),
          ),
          SwitchListTile(
            title: const Text('Enable Timer by Default'),
            subtitle: const Text('Automatically start quiz with timer'),
            secondary: const Icon(Icons.timer),
            value: _enableTimerByDefault,
            onChanged: (value) {
              setState(() => _enableTimerByDefault = value);
              _saveSetting('enable_timer_by_default', value);
            },
          ),
          if (_enableTimerByDefault)
            ListTile(
              leading: const SizedBox(width: 40),
              title: const Text('Default Timer Duration'),
              subtitle: Text('$_defaultTimerMinutes minutes'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTimerDurationDialog(),
            ),
          const Divider(),

          // Notifications Section
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            title: const Text('Enable Reminders'),
            subtitle: const Text('Get reminded to practice'),
            secondary: const Icon(Icons.notifications),
            value: _notificationsEnabled,
            onChanged: (value) async {
              if (value) {
                // Check and request all necessary permissions
                final permissionsGranted =
                    await _checkAndRequestNotificationPermissions();

                if (!permissionsGranted) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '❌ Permissions not granted. Reminders cannot be enabled.',
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  return; // Don't enable notifications
                }
              }

              setState(() => _notificationsEnabled = value);
              await _saveSetting('notifications_enabled', value);

              final notificationService = NotificationService();
              if (value) {
                // Schedule notifications based on current settings
                await notificationService.updateFromPreferences();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '✅ Reminders enabled! You\'ll be notified at $_notificationTime',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );

                  // Show pending notifications count
                  final pending = await notificationService
                      .getPendingNotifications();
                  if (mounted && pending.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '📅 ${pending.length} reminder(s) scheduled',
                        ),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                }
              } else {
                // Cancel all notifications
                await notificationService.cancelAllNotifications();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminders disabled')),
                  );
                }
              }
            },
          ),
          if (_notificationsEnabled) ...[
            ListTile(
              leading: const SizedBox(width: 40),
              title: const Text('Reminder Time'),
              subtitle: Text(_notificationTime),
              trailing: const Icon(Icons.access_time),
              onTap: () => _showTimePickerDialog(),
            ),
            ListTile(
              leading: const SizedBox(width: 40),
              title: const Text('Check Notification Status'),
              subtitle: const Text('View permissions and troubleshoot'),
              trailing: const Icon(Icons.info_outline),
              onTap: () => _showNotificationStatusDialog(),
            ),
            ListTile(
              leading: const SizedBox(width: 40),
              title: const Text('Test Notification'),
              subtitle: const Text('Send immediate test notification'),
              trailing: const Icon(Icons.notifications_active),
              onTap: () async {
                final notificationService = NotificationService();
                await notificationService.showImmediateNotification(
                  title: '🎯 Quiz Reminder',
                  body:
                      'Time to practice! This is how your reminders will look.',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '✅ Test notification sent! Check your notification tray.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const SizedBox(width: 40),
              title: const Text('Days'),
              subtitle: Text(_getSelectedDaysText()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDaysDialog(),
            ),
          ],
          const Divider(),

          // AI Generation Section
          _buildSectionHeader('AI Quiz Generation'),
          ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('AI providers'),
            subtitle: const Text('Keys, models, prices, and connection tests'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.pushNamed(context, '/ai-providers'),
          ),
          const Divider(),

          // Data & Storage Section
          _buildSectionHeader('Data & Storage'),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('Clear Cache'),
            subtitle: const Text('Free up storage space'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _clearCache,
          ),
          const Divider(),

          // About Section
          _buildSectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('App Features'),
            subtitle: const Text('View all implemented features'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('MCQ Quizzer - Features'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '🎯 MCQ Quizzer - A comprehensive quiz application\n\n'
                      '📚 CORE FEATURES:\n'
                      '• Upload MCQ questions from PDF/DOCX files\n'
                      '• Three scoring systems (Straight, Minus Not Carried Over, Minus Carried Over)\n'
                      '• Timer mode for timed quizzes (30-120 minutes)\n'
                      '• Flashcard mode for learning and review\n'
                      '• Save and resume quiz progress\n'
                      '• Add personal notes to questions\n'
                      '• Performance tracking with detailed dashboard\n'
                      '• Dark/Light theme support\n\n'
                      '🔔 NOTIFICATION SYSTEM:\n'
                      '• Flexible daily reminders (choose any days of the week)\n'
                      '• Customizable reminder time\n'
                      '• Automatic timezone detection\n'
                      '• Test notification feature\n\n'
                      '⚙️ CUSTOMIZATION:\n'
                      '• Configurable default quiz settings\n'
                      '• Multiple scoring method preferences\n'
                      '• Timer duration presets\n'
                      '• Notification preferences\n\n'
                      '📱 CROSS-PLATFORM:\n'
                      '• Android & iOS support\n'
                      '• Material Design 3 interface\n'
                      '• Responsive layout\n\n'
                      'Built with Flutter & Material Design 3',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('View Notification Diagnostics'),
            subtitle: const Text(
              'Show latest diagnostics in a copyable dialog (for emulator)',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final notificationService = NotificationService();
              final diag = await notificationService.getDiagnosticsString();
              if (!mounted) return;
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Notification Diagnostics'),
                  content: SingleChildScrollView(child: SelectableText(diag)),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: diag));
                        Navigator.pop(context);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Diagnostics copied to clipboard'),
                            ),
                          );
                        }
                      },
                      child: const Text('Copy'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _showScoringMethodDialog() async {
    final selected = await showDialog<ScoringMethod>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Default Scoring Method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ScoringMethod.values.map((method) {
            return RadioListTile<ScoringMethod>(
              title: Text(method.name.toUpperCase()),
              subtitle: Text(_getScoringMethodDescription(method)),
              value: method,
              groupValue: _defaultScoringMethod,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null) {
      setState(() => _defaultScoringMethod = selected);
      await _saveSetting('default_scoring_method', selected.name);
    }
  }

  String _getScoringMethodDescription(ScoringMethod method) {
    switch (method) {
      case ScoringMethod.straight:
        return 'Count correct answers only';
      case ScoringMethod.minusNotCarriedOver:
        return 'Deduct for wrong (min 0 per question)';
      case ScoringMethod.minusCarriedOver:
        return 'Cumulative penalties (can be negative)';
    }
  }

  Future<void> _showTimerDurationDialog() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Timer Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [30, 45, 60, 90, 120].map((minutes) {
            return RadioListTile<int>(
              title: Text('$minutes minutes'),
              value: minutes,
              groupValue: _defaultTimerMinutes,
              onChanged: (value) => Navigator.pop(context, value),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null) {
      setState(() => _defaultTimerMinutes = selected);
      await _saveSetting('default_timer_minutes', selected);
    }
  }

  Future<void> _showTimePickerDialog() async {
    final timeParts = _notificationTime.split(':');
    final initialTime = TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      final formattedTime =
          '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
      setState(() => _notificationTime = formattedTime);
      await _saveSetting('notification_time', formattedTime);

      // Reschedule notifications with new time if enabled
      if (_notificationsEnabled) {
        final notificationService = NotificationService();
        await notificationService.updateFromPreferences();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder time updated to $formattedTime'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  String _getSelectedDaysText() {
    if (_selectedDays.isEmpty) return 'None';
    if (_selectedDays.length == 7) return 'Every day';
    if (_selectedDays.length == 1) return _selectedDays.first.toUpperCase();

    final shortNames = _selectedDays
        .map((day) => day.substring(0, 3).toUpperCase())
        .toList();
    return shortNames.join(', ');
  }

  Future<void> _showDaysDialog() async {
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    final tempSelected = List<String>.from(_selectedDays);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Select Days'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: days.map((day) {
              return CheckboxListTile(
                title: Text(day.toUpperCase()),
                value: tempSelected.contains(day),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      tempSelected.add(day);
                    } else {
                      tempSelected.remove(day);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  tempSelected.clear();
                  tempSelected.addAll(days);
                });
              },
              child: const Text('Select All'),
            ),
            ElevatedButton(
              onPressed: () {
                if (tempSelected.isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == true && tempSelected.isNotEmpty) {
      setState(() => _selectedDays = tempSelected);
      await _saveSetting('notification_days', tempSelected.join(','));

      // Reschedule notifications with new days if enabled
      if (_notificationsEnabled) {
        final notificationService = NotificationService();
        await notificationService.updateFromPreferences();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder days updated'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  /// Show detailed notification status and troubleshooting information
  Future<void> _showNotificationStatusDialog() async {
    final notificationService = NotificationService();
    await notificationService.initialize();

    // Check all permissions
    final notificationsEnabled = await notificationService
        .areNotificationsEnabled();
    final canScheduleExact = await notificationService.canScheduleExactAlarms();
    final pending = await notificationService.getPendingNotifications();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Notification Status'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusRow('Notifications Enabled', notificationsEnabled),
              _buildStatusRow('Exact Alarms Permission', canScheduleExact),
              const Divider(),
              Text(
                'Pending Reminders: ${pending.length}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (pending.isEmpty)
                const Text(
                  'No reminders scheduled',
                  style: TextStyle(color: Colors.grey),
                )
              else
                ...pending.map(
                  (p) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '• ${p.title}: ${p.body}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              const Divider(),
              const SizedBox(height: 8),
              if (!notificationsEnabled || !canScheduleExact) ...[
                const Text(
                  '⚠️ Issues Found',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (!notificationsEnabled)
                  const Text(
                    '❌ Notifications are disabled. Enable them in system settings.',
                  ),
                if (!canScheduleExact)
                  const Text(
                    '❌ Exact alarms permission not granted. Required for reliable reminders on Android 12+.',
                  ),
              ] else ...[
                const Text(
                  '✅ Everything looks good!',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!notificationsEnabled || !canScheduleExact)
            TextButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              onPressed: () {
                notificationService.requestPermissions();
                Navigator.pop(context);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
