import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_service.dart';
import 'email_auth_dialog.dart';
import 'google_sheets_service.dart';
import 'simple_ble_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<DaySchedule> _schedule = [];
  final SimpleBLEService _bleService = SimpleBLEService();
  bool _isLoading = true;
  final AuthService _authService = AuthService();

  // Construction site towers
  static const List<String> availableTowers = [
    'Tower A', 'Tower B', 'Tower C', 'Tower D',
    'Tower E', 'Tower F', 'Main Office', 'Parking Garage',
    'Security Office', 'Storage Building', 'Equipment Shed', 'Site Trailer'
  ];

  @override
  void initState() {
    super.initState();
    _initializeAuth();
    _generateSchedule();
    _loadSchedule();
  }

  Future<void> _initializeAuth() async {
    await _authService.initialize();
    setState(() {}); // Refresh UI with auth state
  }

  void _generateSchedule() {
    // Use actual current date for real deployment
    final now = DateTime.now();
    
    _schedule = List.generate(7, (index) {
      final date = now.add(Duration(days: index));
      return DaySchedule(
        date: date,
        isToday: index == 0,
        startTime: null,
        endTime: null,
        isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        holidayName: _getHolidayName(date),
      );
    });
  }

  Future<void> _loadSchedule() async {
    try {
      // Load exclusively from Google Sheets - no local storage
      final onlineData = await GoogleSheetsService.loadSchedule();
      
      if (onlineData != null) {
        // Handle new format with nested 'schedule' object
        final scheduleData = onlineData.containsKey('schedule') 
            ? onlineData['schedule'] as Map<String, dynamic>
            : onlineData;
            
        setState(() {
          for (int i = 0; i < _schedule.length; i++) {
            final dateKey = _schedule[i].date.toIso8601String().split('T')[0];
            if (scheduleData.containsKey(dateKey)) {
              final dayData = scheduleData[dateKey] as Map<String, dynamic>;
              
              // Parse tower selections (handle both old and new format)
              Set<String> towers = {};
              if (dayData.containsKey('selectedTowers')) {
                final towersList = dayData['selectedTowers'] as List?;
                if (towersList != null) {
                  towers = Set<String>.from(towersList);
                }
              }
              
              _schedule[i] = _schedule[i].copyWith(
                startTime: dayData['startTime'] != null 
                    ? TimeOfDay.fromDateTime(DateTime.parse('2000-01-01T${dayData['startTime']}:00'))
                    : null,
                endTime: dayData['endTime'] != null
                    ? TimeOfDay.fromDateTime(DateTime.parse('2000-01-01T${dayData['endTime']}:00'))
                    : null,
                wholeProperty: dayData['wholeProperty'] ?? true,
                selectedTowers: towers,
              );
            }
          }
          _isLoading = false;
        });
        
        // Show who last updated the schedule
        if (onlineData.containsKey('updatedBy') && mounted) {
          final updatedBy = onlineData['updatedBy'];
          if (updatedBy != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Schedule loaded - Last updated by: $updatedBy'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        print('⚠️ No schedule data found in Google Sheets - using default empty schedule');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Failed to load schedule from Google Sheets: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading schedule from Google Sheets: $e')),
        );
      }
    }
  }

  Future<void> _saveSchedule() async {
    if (!_authService.getUserPermission().canSave) {
      return; // Silently fail if no permission - this is called by auto-save
    }
    
    try {
      // Prepare schedule data including tower selections
      final Map<String, dynamic> scheduleData = {
        'lastUpdated': DateTime.now().toIso8601String(),
        'updatedBy': _authService.userEmail,
        'schedule': {},
      };
      
      for (final day in _schedule) {
        final dateKey = day.date.toIso8601String().split('T')[0];
        scheduleData['schedule'][dateKey] = {
          'startTime': day.startTime != null 
              ? '${day.startTime!.hour.toString().padLeft(2, '0')}:${day.startTime!.minute.toString().padLeft(2, '0')}'
              : null,
          'endTime': day.endTime != null
              ? '${day.endTime!.hour.toString().padLeft(2, '0')}:${day.endTime!.minute.toString().padLeft(2, '0')}'
              : null,
          'wholeProperty': day.wholeProperty,
          'selectedTowers': day.selectedTowers.toList(),
        };
      }
      
      // Save exclusively to Google Sheets - no local storage
      await _saveToOnlineStorage(scheduleData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Schedule saved to Google Sheets!'),
                const SizedBox(height: 4),
                const Text(
                  'View: https://docs.google.com/spreadsheets/d/19rEowCX2VNAKG25Fu1T9p-GRUWzlqg8RPjvT-jmFm-A/edit',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('❌ Failed to save to Google Sheets: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveToOnlineStorage(Map<String, dynamic> data) async {
    // Save to Google Sheets for team access
    print('📊 Saving to Google Sheets...');
    
    try {
      await GoogleSheetsService.updateSchedule(data);
      print('✅ Data saved to Google Sheets successfully!');
    } catch (e) {
      print('🚨 Exception saving to Google Sheets: $e');
      rethrow;
    }
  }

  Future<void> _clearSchedule() async {
    if (!_authService.getUserPermission().canClear) {
      _showPermissionDeniedDialog();
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Schedule'),
        content: const Text('Are you sure you want to clear all schedule data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        for (int i = 0; i < _schedule.length; i++) {
          _schedule[i] = _schedule[i].copyWith(
            startTime: null,
            endTime: null,
          );
        }
      });
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('weekly_schedule');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Schedule cleared!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _showSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Summary'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final day in _schedule)
                if (day.startTime != null || day.endTime != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getDayName(day.date),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                _getDateString(day.date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${_formatHourOnly(day.startTime)} - ${_formatHourOnly(day.endTime)}',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                      ],
                    ),
                  ),
              if (_schedule.every((day) => day.startTime == null && day.endTime == null))
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No schedule entries found.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectTime(int dayIndex, bool isStartTime) async {
    // Check if user has permission to edit
    if (!_authService.getUserPermission().canEdit) {
      _showPermissionDeniedDialog();
      return;
    }
    
    final currentTime = isStartTime 
        ? _schedule[dayIndex].startTime 
        : _schedule[dayIndex].endTime;
    
    // Show hour-only picker dialog
    final int? selectedHour = await showDialog<int>(
      context: context,
      builder: (context) => _HourPickerDialog(
        initialHour: currentTime?.hour ?? (isStartTime ? 8 : 17),
        isStartTime: isStartTime,
        dayColors: _getDayColors(dayIndex),
      ),
    );

    if (selectedHour != null) {
      final pickedTime = TimeOfDay(hour: selectedHour, minute: 0);
      setState(() {
        if (isStartTime) {
          _schedule[dayIndex] = _schedule[dayIndex].copyWith(startTime: pickedTime);
        } else {
          _schedule[dayIndex] = _schedule[dayIndex].copyWith(endTime: pickedTime);
        }
      });
      
      // Auto-save after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _saveSchedule();
      });
      
      // If BLE is connected and this is a start time change, send test message
      if (isStartTime && _bleService.isConnected) {
        await _sendBLETestMessage();
      }
    }
  }

  Future<void> _sendBLETestMessage() async {
    try {
      await _bleService.sendMessage('test');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📤 Sent "test" message to ${_bleService.deviceName}'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ BLE message error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _connectToBLE() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Connecting to Bluetooth device...'),
            ],
          ),
        ),
      );

      // Attempt connection
      final bool connected = await _bleService.connectToAnyDevice();
      
      // Close loading dialog
      Navigator.of(context).pop();

      if (connected) {
        // Show success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Connected to ${_bleService.deviceName}'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // Refresh UI to show connected status
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to connect to Bluetooth device'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Bluetooth error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _disconnectBLE() {
    _bleService.disconnect();
    setState(() {}); // Refresh UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔌 Disconnected from Bluetooth device'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  Color _getDayColors(int dayIndex) {
    if (_schedule[dayIndex].isToday) {
      return Colors.green;
    } else if (_schedule[dayIndex].holidayName != null) {
      return Colors.red;
    } else if (_schedule[dayIndex].isWeekend) {
      return Colors.blue;
    }
    return Colors.blue;
  }

  String _formatHourOnly(TimeOfDay? time) {
    if (time == null) return '--';
    final hour = time.hour;
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }

  void _toggleWholeProperty(int dayIndex, bool value) {
    if (!_authService.getUserPermission().canEdit) {
      _showPermissionDeniedDialog();
      return;
    }
    
    setState(() {
      _schedule[dayIndex] = _schedule[dayIndex].copyWith(
        wholeProperty: value,
        selectedTowers: value ? <String>{} : _schedule[dayIndex].selectedTowers,
      );
    });
    
    // Auto-save after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _saveSchedule();
    });
  }

  void _showTowerSelection(int dayIndex) {
    if (!_authService.getUserPermission().canEdit) {
      _showPermissionDeniedDialog();
      return;
    }

    showDialog(
      context: context,
      builder: (context) => TowerSelectionDialog(
        availableTowers: availableTowers,
        selectedTowers: _schedule[dayIndex].selectedTowers,
        onSelectionChanged: (selectedTowers) {
          setState(() {
            _schedule[dayIndex] = _schedule[dayIndex].copyWith(
              selectedTowers: selectedTowers,
            );
          });
          
          // Auto-save after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            _saveSchedule();
          });
        },
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You need to be logged in as an admin to edit schedules.'),
            const SizedBox(height: 16),
            const Text('Only authorized admin users can make changes.'),
            const SizedBox(height: 8),
            const Text('Others can view but not edit.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          if (!_authService.isLoggedIn)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showEmailAuthDialog();
              },
              child: const Text('Sign In'),
            ),
        ],
      ),
    );
  }

  void _showEmailAuthDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EmailAuthDialog(
        authService: _authService,
        onAuthSuccess: () {
          setState(() {}); // Refresh UI
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Signed in as ${_authService.userEmail}'),
              backgroundColor: _authService.isAdmin ? Colors.green : Colors.orange,
            ),
          );
        },
      ),
    );
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    setState(() {}); // Refresh UI
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed out successfully'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String _getDayName(DateTime date) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[date.weekday - 1];
  }

  String _getDateString(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String? _getHolidayName(DateTime date) {
    final year = date.year;
    final month = date.month;
    final day = date.day;

    // Fixed date holidays
    if (month == 1 && day == 1) return "New Year's Day";
    if (month == 7 && day == 4) return "Independence Day";
    if (month == 11 && day == 11) return "Veterans Day";
    if (month == 12 && day == 25) return "Christmas Day";

    // MLK Day - Third Monday in January
    if (month == 1) {
      final firstMonday = _getFirstMondayOfMonth(year, month);
      if (day == firstMonday + 14) return "Martin Luther King Jr. Day";
    }

    // Presidents Day - Third Monday in February
    if (month == 2) {
      final firstMonday = _getFirstMondayOfMonth(year, month);
      if (day == firstMonday + 14) return "Presidents Day";
    }

    // Memorial Day - Last Monday in May
    if (month == 5) {
      final lastMonday = _getLastMondayOfMonth(year, month);
      if (day == lastMonday) return "Memorial Day";
    }

    // Labor Day - First Monday in September
    if (month == 9) {
      final firstMonday = _getFirstMondayOfMonth(year, month);
      if (day == firstMonday) return "Labor Day";
    }

    // Columbus Day - Second Monday in October
    if (month == 10) {
      final firstMonday = _getFirstMondayOfMonth(year, month);
      if (day == firstMonday + 7) return "Columbus Day";
    }

    // Thanksgiving - Fourth Thursday in November
    if (month == 11) {
      final firstThursday = _getFirstThursdayOfMonth(year, month);
      if (day == firstThursday + 21) return "Thanksgiving Day";
      // Black Friday - Day after Thanksgiving
      if (day == firstThursday + 22) return "Black Friday";
    }

    return null;
  }

  int _getFirstMondayOfMonth(int year, int month) {
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstOfMonth.weekday;
    // If first day is Monday (1), return 1, otherwise calculate
    return firstWeekday == 1 ? 1 : 8 - firstWeekday + 1;
  }

  int _getLastMondayOfMonth(int year, int month) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final lastOfMonth = DateTime(year, month, lastDayOfMonth);
    final lastWeekday = lastOfMonth.weekday;
    // Calculate last Monday
    return lastDayOfMonth - (lastWeekday == 7 ? 6 : lastWeekday - 1);
  }

  int _getFirstThursdayOfMonth(int year, int month) {
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstOfMonth.weekday;
    // Thursday is weekday 4
    return firstWeekday <= 4 ? 4 - firstWeekday + 1 : 11 - firstWeekday;
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Weekly Schedule Planner'),
            Row(
              children: [
                const Text(
                  'Test Mode: Nov 25, 2025',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
                const SizedBox(width: 8),
                if (_authService.isLoggedIn)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _authService.isAdmin ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _authService.getUserPermission().displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // BLE Connection Status & Button (available to everyone)
          IconButton(
            icon: Icon(
              _bleService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
              color: _bleService.isConnected ? Colors.blue : Colors.grey,
            ),
            onPressed: _bleService.isConnected ? _disconnectBLE : _connectToBLE,
            tooltip: _bleService.isConnected 
                ? 'Connected to ${_bleService.deviceName}\nTap to disconnect'
                : 'Connect to Smart Key via Bluetooth',
          ),
          if (_bleService.isConnected)
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: _sendBLETestMessage,
              tooltip: 'Send test message to connected device',
            ),
          // User info and sign in/out
          if (!_authService.isLoggedIn)
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _showEmailAuthDialog,
              tooltip: 'Sign In with SMS',
            )
          else
            PopupMenuButton<String>(
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: _authService.isAdmin ? Colors.green : Colors.orange,
                child: Text(
                  _authService.isAdmin ? 'A' : '?',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              onSelected: (value) {
                if (value == 'signout') {
                  _signOut();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _authService.userDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _authService.userEmail,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      Text(
                        'Permission: ${_authService.getUserPermission().displayName}',
                        style: const TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'signout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Sign Out'),
                  ),
                ),
              ],
            ),
          // Other menu items
          IconButton(
            icon: const Icon(Icons.summarize),
            onPressed: _showSummary,
            tooltip: 'Show Summary',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'save':
                  if (_authService.getUserPermission().canSave) {
                    _saveSchedule();
                  } else {
                    _showPermissionDeniedDialog();
                  }
                  break;
                case 'clear':
                  _clearSchedule(); // This method already checks permissions
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'save',
                enabled: _authService.getUserPermission().canSave,
                child: ListTile(
                  leading: Icon(
                    Icons.save,
                    color: _authService.getUserPermission().canSave 
                        ? null 
                        : Colors.grey,
                  ),
                  title: Text(
                    'Save Schedule',
                    style: TextStyle(
                      color: _authService.getUserPermission().canSave 
                          ? null 
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                enabled: _authService.getUserPermission().canClear,
                child: ListTile(
                  leading: Icon(
                    Icons.clear_all,
                    color: _authService.getUserPermission().canClear 
                        ? null 
                        : Colors.grey,
                  ),
                  title: Text(
                    'Clear All',
                    style: TextStyle(
                      color: _authService.getUserPermission().canClear 
                          ? null 
                          : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade300, Colors.purple.shade300],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Plan your upcoming week with start and end times',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildLegendItem('Today', Colors.green),
                    _buildLegendItem('Holiday', Colors.red),
                    _buildLegendItem('Weekend', Colors.blue),
                    _buildLegendItem('Weekday', Colors.grey),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _schedule.length,
              itemBuilder: (context, index) {
                final day = _schedule[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: day.isToday ? 8 : 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: day.isToday 
                        ? const BorderSide(color: Colors.green, width: 2)
                        : day.holidayName != null
                            ? const BorderSide(color: Colors.red, width: 2)
                            : day.isWeekend
                                ? const BorderSide(color: Colors.blue, width: 1)
                                : BorderSide.none,
                  ),
                  child: Container(
                    decoration: day.isToday
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: [Colors.green.shade50, Colors.green.shade100],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          )
                        : day.holidayName != null
                            ? BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [Colors.red.shade50, Colors.red.shade100],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              )
                            : day.isWeekend
                                ? BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  )
                                : null,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _getDayName(day.date),
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: day.holidayName != null 
                                                ? Colors.red.shade700
                                                : day.isWeekend 
                                                    ? Colors.blue.shade700
                                                    : Colors.black,
                                          ),
                                        ),
                                        if (day.isWeekend && day.holidayName == null)
                                          Container(
                                            margin: const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'Weekend',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    Text(
                                      _getDateString(day.date),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    if (day.holidayName != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.celebration,
                                              size: 16,
                                              color: Colors.red.shade600,
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                day.holidayName!,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.red.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  if (day.isToday)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Today',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (day.holidayName != null && !day.isToday)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Holiday',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Compact time controls and tower selection
                          Row(
                            children: [
                              // Compact start time
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () => _selectTime(index, true),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Start', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        Text(
                                          _formatHourOnly(day.startTime),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Compact end time
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () => _selectTime(index, false),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('End', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                        Text(
                                          _formatHourOnly(day.endTime),
                                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Whole property checkbox
                              Expanded(
                                flex: 3,
                                child: CheckboxListTile(
                                  title: const Text('Whole Property', style: TextStyle(fontSize: 12)),
                                  value: day.wholeProperty,
                                  onChanged: _authService.getUserPermission().canEdit 
                                      ? (value) => _toggleWholeProperty(index, value ?? true)
                                      : null,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  controlAffinity: ListTileControlAffinity.leading,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Select towers button (only shown when whole property is off)
                          if (!day.wholeProperty)
                            Container(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _authService.getUserPermission().canEdit 
                                    ? () => _showTowerSelection(index)
                                    : null,
                                icon: const Icon(Icons.business, size: 18),
                                label: Text(
                                  day.selectedTowers.isEmpty 
                                      ? 'Select Towers'
                                      : '${day.selectedTowers.length} Tower${day.selectedTowers.length == 1 ? '' : 's'} Selected',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // No manual save button needed - everything auto-saves!
      floatingActionButton: _authService.getUserPermission().canEdit
          ? FloatingActionButton.extended(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Auto-save enabled - All changes sync automatically!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              backgroundColor: Colors.green,
              icon: const Icon(Icons.cloud_done),
              label: const Text('Auto-Save ON'),
            )
          : FloatingActionButton.extended(
              onPressed: _showPermissionDeniedDialog,
              backgroundColor: Colors.grey,
              icon: const Icon(Icons.lock),
              label: const Text('Read Only'),
            ),
    );
  }
}

class DaySchedule {
  final DateTime date;
  final bool isToday;
  final TimeOfDay? startTime;
  final TimeOfDay? endTime;
  final bool isWeekend;
  final String? holidayName;
  final bool wholeProperty;
  final Set<String> selectedTowers;

  DaySchedule({
    required this.date,
    required this.isToday,
    this.startTime,
    this.endTime,
    required this.isWeekend,
    this.holidayName,
    this.wholeProperty = true,
    this.selectedTowers = const {},
  });

  DaySchedule copyWith({
    DateTime? date,
    bool? isToday,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    bool? isWeekend,
    String? holidayName,
    bool? wholeProperty,
    Set<String>? selectedTowers,
  }) {
    return DaySchedule(
      date: date ?? this.date,
      isToday: isToday ?? this.isToday,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isWeekend: isWeekend ?? this.isWeekend,
      holidayName: holidayName ?? this.holidayName,
      wholeProperty: wholeProperty ?? this.wholeProperty,
      selectedTowers: selectedTowers ?? this.selectedTowers,
    );
  }
}

class TowerSelectionDialog extends StatefulWidget {
  final List<String> availableTowers;
  final Set<String> selectedTowers;
  final Function(Set<String>) onSelectionChanged;

  const TowerSelectionDialog({
    super.key,
    required this.availableTowers,
    required this.selectedTowers,
    required this.onSelectionChanged,
  });

  @override
  State<TowerSelectionDialog> createState() => _TowerSelectionDialogState();
}

class _TowerSelectionDialogState extends State<TowerSelectionDialog> {
  late Set<String> _selectedTowers;

  @override
  void initState() {
    super.initState();
    _selectedTowers = Set.from(widget.selectedTowers);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Towers/Buildings'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: widget.availableTowers.length,
          itemBuilder: (context, index) {
            final tower = widget.availableTowers[index];
            final isSelected = _selectedTowers.contains(tower);
            
            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedTowers.remove(tower);
                  } else {
                    _selectedTowers.add(tower);
                  }
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue.shade100 : Colors.grey.shade100,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isSelected) 
                        const Icon(Icons.check_circle, color: Colors.blue, size: 16),
                      if (isSelected) const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          tower,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.blue.shade700 : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _selectedTowers.clear();
            });
          },
          child: const Text('Clear All'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedTowers = Set.from(widget.availableTowers);
            });
          },
          child: const Text('Select All'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSelectionChanged(_selectedTowers);
            Navigator.of(context).pop();
          },
          child: Text('Save (${_selectedTowers.length})'),
        ),
      ],
    );
  }
}

class _HourPickerDialog extends StatelessWidget {
  final int initialHour;
  final bool isStartTime;
  final Color dayColors;

  const _HourPickerDialog({
    required this.initialHour,
    required this.isStartTime,
    required this.dayColors,
  });

  @override
  Widget build(BuildContext context) {
    // Generate hours from 6 AM to 11 PM for construction sites
    final hours = List.generate(18, (index) => index + 6);
    
    return AlertDialog(
      title: Text(isStartTime ? 'Select Start Hour' : 'Select End Hour'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: hours.length,
          itemBuilder: (context, index) {
            final hour = hours[index];
            final isSelected = hour == initialHour;
            final displayText = _formatHour(hour);
            
            return InkWell(
              onTap: () => Navigator.of(context).pop(hour),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? dayColors.withOpacity(0.2) : Colors.grey.shade100,
                  border: Border.all(
                    color: isSelected ? dayColors : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    displayText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? dayColors : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (isStartTime)
          TextButton(
            onPressed: () => Navigator.of(context).pop(null), // Clear time
            child: const Text('Clear'),
          ),
      ],
    );
  }

  String _formatHour(int hour) {
    if (hour == 0) return '12 AM';
    if (hour < 12) return '$hour AM';
    if (hour == 12) return '12 PM';
    return '${hour - 12} PM';
  }
}