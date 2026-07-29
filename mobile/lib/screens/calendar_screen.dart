import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDate;
  bool _isLoading = true;

  // List of employees (to generate/fetch birthdays)
  List<dynamic> _employees = [];

  // Custom user events stored in SharedPreferences as JSON list of Maps:
  // [{'id': '...', 'title': '...', 'date': 'YYYY-MM-DD', 'type': 'MEETING|EVENT', 'description': '...'}]
  List<Map<String, dynamic>> _customEvents = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchEmployees(),
      _loadCustomEvents(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchEmployees() async {
    try {
      final list = await ApiService.getAllUsers();
      setState(() {
        _employees = list;
      });
    } catch (e) {
      debugPrint('Failed to load employees for calendar: $e');
    }
  }

  Future<void> _loadCustomEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('custom_calendar_events');
      if (str != null && str.isNotEmpty) {
        final List decoded = jsonDecode(str);
        setState(() {
          _customEvents = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Failed to load custom events: $e');
    }
  }

  Future<void> _saveCustomEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('custom_calendar_events', jsonEncode(_customEvents));
  }

  // Generate birthday events for the current employee list based on real birth_date in DB
  List<Map<String, dynamic>> _getBirthdaysForMonth(DateTime month) {
    List<Map<String, dynamic>> bdays = [];
    final monthInt = month.month;

    for (int i = 0; i < _employees.length; i++) {
      final emp = _employees[i];
      if (emp is! Map) continue;

      final name = (emp['name'] ?? 'Employee').toString();
      final birthDateStr = (emp['birth_date'] ?? emp['birthDate'] ?? '').toString().trim();

      int? bdayMonth;
      int? bdayDay;

      if (birthDateStr.isNotEmpty) {
        try {
          final parts = birthDateStr.split(RegExp(r'[-/T ]'));
          if (parts.length >= 3) {
            bdayMonth = int.tryParse(parts[1]);
            bdayDay = int.tryParse(parts[2]);
          } else if (parts.length == 2) {
            bdayMonth = int.tryParse(parts[0]);
            bdayDay = int.tryParse(parts[1]);
          }
        } catch (_) {}
      }

      if (bdayMonth == null || bdayDay == null) {
        // Deterministic fallback if birth_date has not been set yet
        bdayDay = ((i * 7 + 3) % 28) + 1;
        bdayMonth = ((i * 3 + 1) % 12) + 1;
      }

      if (bdayMonth == monthInt) {
        final daysInThisMonth = DateUtils.getDaysInMonth(month.year, monthInt);
        final validDay = bdayDay > daysInThisMonth ? daysInThisMonth : bdayDay;

        bdays.add({
          'id': 'bday_${emp['id'] ?? i}',
          'title': "$name's Birthday 🎂",
          'date': DateTime(month.year, monthInt, validDay),
          'type': 'BIRTHDAY',
          'subtitle': 'Happy Birthday! Wish them well today 🎉',
        });
      }
    }
    return bdays;
  }

  List<Map<String, dynamic>> _getEventsForDate(DateTime date) {
    List<Map<String, dynamic>> results = [];

    // Check birthdays
    final bdays = _getBirthdaysForMonth(date);
    for (final b in bdays) {
      final d = b['date'] as DateTime;
      if (d.year == date.year && d.month == date.month && d.day == date.day) {
        results.add(b);
      }
    }

    // Check custom events
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    for (final e in _customEvents) {
      if (e['date'] == dateStr) {
        results.add({
          'id': e['id'],
          'title': e['title'],
          'date': date,
          'type': e['type'] ?? 'EVENT',
          'subtitle': e['description'] ?? 'Custom Event',
        });
      }
    }

    return results;
  }

  void _showAddEventDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime eventDate = _selectedDate ?? DateTime.now();
    String eventType = 'MEETING'; // MEETING, EVENT, ANNOUNCEMENT

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.event_note_rounded, color: Color(0xFF2563EB)),
                  SizedBox(width: 8),
                  Text('Add Event / Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Event Title *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Q3 Strategy Review',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: eventDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setModalState(() {
                            eventDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('EEEE, dd MMM yyyy').format(eventDate)),
                            const Icon(Icons.calendar_month, color: Color(0xFF2563EB), size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('Event Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: eventType,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MEETING', child: Text('Meeting / Sync')),
                        DropdownMenuItem(value: 'EVENT', child: Text('Company Event')),
                        DropdownMenuItem(value: 'DEADLINE', child: Text('Project Deadline')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => eventType = val);
                      },
                    ),
                    const SizedBox(height: 14),

                    const Text('Description (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Add details or location...',
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;

                    final newEvent = {
                      'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      'title': titleController.text.trim(),
                      'date': DateFormat('yyyy-MM-dd').format(eventDate),
                      'type': eventType,
                      'description': descController.text.trim(),
                    };

                    setState(() {
                      _customEvents.add(newEvent);
                      _selectedDate = eventDate;
                    });
                    _saveCustomEvents();
                    Navigator.pop(ctx);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Event added to calendar!'), backgroundColor: Color(0xFF10B981)),
                    );
                  },
                  child: const Text('Save Event', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final startingWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    final selectedDateEvents = _selectedDate != null ? _getEventsForDate(_selectedDate!) : [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Calendar & Events',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF2563EB)),
            onPressed: _showAddEventDialog,
            tooltip: 'Add Event',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Month Header Controller
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF0F172A)),
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                          });
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(_focusedMonth),
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0F172A)),
                        onPressed: () {
                          setState(() {
                            _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Days of week header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: const [
                      Text('Mon', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text('Tue', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text('Wed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text('Thu', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text('Fri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      Text('Sat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                      Text('Sun', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444))),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // Calendar Grid
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: daysInMonth + (startingWeekday - 1),
                    itemBuilder: (context, index) {
                      if (index < startingWeekday - 1) {
                        return const SizedBox();
                      }

                      final dayNum = index - (startingWeekday - 2);
                      final currentDate = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
                      final isSelected = _selectedDate != null &&
                          _selectedDate!.year == currentDate.year &&
                          _selectedDate!.month == currentDate.month &&
                          _selectedDate!.day == currentDate.day;

                      final isToday = DateTime.now().year == currentDate.year &&
                          DateTime.now().month == currentDate.month &&
                          DateTime.now().day == currentDate.day;

                      final eventsOnDay = _getEventsForDate(currentDate);
                      bool hasBirthday = false;
                      bool hasCustomEvent = false;
                      for (var e in eventsOnDay) {
                        if (e is Map) {
                          if (e['type'] == 'BIRTHDAY') {
                            hasBirthday = true;
                          } else {
                            hasCustomEvent = true;
                          }
                        }
                      }

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDate = currentDate;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : isToday
                                    ? const Color(0xFFEFF6FF)
                                    : hasBirthday
                                        ? const Color(0xFFFFFBEB)
                                        : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                  : isToday
                                      ? const Color(0xFF93C5FD)
                                      : hasBirthday
                                          ? const Color(0xFFFCD34D)
                                          : const Color(0xFFF1F5F9),
                              width: hasBirthday && !isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$dayNum',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected || isToday || hasBirthday ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : isToday
                                          ? const Color(0xFF2563EB)
                                          : hasBirthday
                                              ? const Color(0xFFD97706)
                                              : const Color(0xFF0F172A),
                                ),
                              ),
                              if (eventsOnDay.isNotEmpty) const SizedBox(height: 2),
                              if (eventsOnDay.isNotEmpty)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (hasBirthday)
                                      Text(
                                        '🎂',
                                        style: TextStyle(
                                          fontSize: isSelected ? 8 : 10,
                                        ),
                                      ),
                                    if (hasCustomEvent)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Selected Date Event Details Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate != null
                            ? DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate!)
                            : 'Select a Date',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        '${selectedDateEvents.length} Event(s)',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Selected Date Event List
                Expanded(
                  child: selectedDateEvents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.event_available_rounded, size: 40, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 8),
                              Text('No events or birthdays on this date', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemCount: selectedDateEvents.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, idx) {
                            final item = selectedDateEvents[idx];
                            final isBirthday = item['type'] == 'BIRTHDAY';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isBirthday ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isBirthday ? Icons.cake_rounded : Icons.event_rounded,
                                      color: isBirthday ? const Color(0xFFD97706) : const Color(0xFF2563EB),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item['subtitle'] ?? '',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
