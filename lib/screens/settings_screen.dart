import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/quiz_service.dart';

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
  String _notificationFrequency = 'daily';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load scoring method
      final scoringMethodName = _prefs.getString('default_scoring_method') ?? 'straight';
      _defaultScoringMethod = ScoringMethod.values.firstWhere(
        (m) => m.name == scoringMethodName,
        orElse: () => ScoringMethod.straight,
      );

      // Load timer settings
      _defaultTimerMinutes = _prefs.getInt('default_timer_minutes') ?? 60;
      _enableTimerByDefault = _prefs.getBool('enable_timer_by_default') ?? false;

      // Load notification settings
      _notificationsEnabled = _prefs.getBool('notifications_enabled') ?? false;
      _notificationTime = _prefs.getString('notification_time') ?? '09:00';
      _notificationFrequency = _prefs.getString('notification_frequency') ?? 'daily';

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
        appBar: AppBar(title: const Text('Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
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
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
              _saveSetting('notifications_enabled', value);
              if (value) {
                _showNotificationPermissionInfo();
              }
            },
          ),
          if (_notificationsEnabled) ...[
            ListTile(
              leading: const SizedBox(width: 40),
              title: const Text('Reminder Time'),
              subtitle: Text(_notificationTime),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showTimePickerDialog(),
            ),
            ListTile(
              leading: const SizedBox(width: 40),
              title: const Text('Frequency'),
              subtitle: Text(_notificationFrequency.toUpperCase()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showFrequencyDialog(),
            ),
          ],
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
            title: const Text('Build Plan'),
            subtitle: const Text('View development documentation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('MCQ Quizzer'),
                  content: const SingleChildScrollView(
                    child: Text(
                      'MCQ Quizzer - A comprehensive quiz application\n\n'
                      'Features:\n'
                      '• Upload MCQ questions from PDF/DOCX files\n'
                      '• Three scoring systems (Straight, Minus Not Carried Over, Minus Carried Over)\n'
                      '• Timer mode for timed quizzes\n'
                      '• Flashcard mode for learning\n'
                      '• Save and resume quiz progress\n'
                      '• Add personal notes to questions\n'
                      '• Track your performance with dashboard\n'
                      '• Dark mode support\n\n'
                      'Developed with Flutter & Material Design 3',
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
    }
  }

  Future<void> _showFrequencyDialog() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reminder Frequency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['daily', 'weekly', 'weekdays'].map((frequency) {
            return RadioListTile<String>(
              title: Text(frequency.toUpperCase()),
              value: frequency,
              groupValue: _notificationFrequency,
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
      setState(() => _notificationFrequency = selected);
      await _saveSetting('notification_frequency', selected);
    }
  }

  void _showNotificationPermissionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Permission'),
        content: const Text(
          'Notifications are currently saved as preferences.\n\n'
          'To enable actual notifications, you will need to grant permission '
          'when prompted by your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
