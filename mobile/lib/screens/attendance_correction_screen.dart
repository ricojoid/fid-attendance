import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AttendanceCorrectionScreen extends StatefulWidget {
  const AttendanceCorrectionScreen({super.key});

  @override
  State<AttendanceCorrectionScreen> createState() => _AttendanceCorrectionScreenState();
}

class _AttendanceCorrectionScreenState extends State<AttendanceCorrectionScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _attendanceDate;
  TimeOfDay? _checkInTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay? _checkOutTime = const TimeOfDay(hour: 17, minute: 0);
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingHistory = true;

  List<dynamic> _attendanceHistory = [];
  List<dynamic> _correctionHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchHistoryData();
  }

  Future<void> _fetchHistoryData() async {
    setState(() => _isLoadingHistory = true);
    try {
      final history = await ApiService.getAttendanceHistory();
      final corrections = await ApiService.getCorrectionHistory();
      setState(() {
        _attendanceHistory = history;
        _correctionHistory = corrections;
      });

      // Auto-select the most recent red (missing) workday if available
      final workdays = _getPastWorkdays();
      for (final d in workdays) {
        if (!_isDateApprovedOrAttended(d)) {
          _attendanceDate = d;
          break;
        }
      }
      _attendanceDate ??= workdays.isNotEmpty ? workdays.first : DateTime.now();
    } catch (e) {
      debugPrint('Error loading attendance history: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  /// Generate past 30 days excluding Saturday (6) and Sunday (7)
  List<DateTime> _getPastWorkdays() {
    List<DateTime> list = [];
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final d = now.subtract(Duration(days: i));
      if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
        list.add(DateTime(d.year, d.month, d.day));
      }
    }
    return list;
  }

  /// Green if checked-in OR approved correction; Red if missing / not approved
  bool _isDateApprovedOrAttended(DateTime date) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // 1. Check if user checked in on this date
    if (_attendanceHistory is List && _attendanceHistory.isNotEmpty) {
      for (var a in _attendanceHistory) {
        if (a is Map && a['date'] == dateStr && a['check_in_time'] != null) {
          return true;
        }
      }
    }

    // 2. Check if user has an APPROVED attendance correction for this date
    if (_correctionHistory is List && _correctionHistory.isNotEmpty) {
      for (var c in _correctionHistory) {
        if (c is Map && c['attendance_date'] == dateStr && c['status'] == 'APPROVED') {
          return true;
        }
      }
    }

    return false;
  }

  void _selectDate() {
    DateTime focusedMonth = _attendanceDate ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final daysInMonth = DateUtils.getDaysInMonth(focusedMonth.year, focusedMonth.month);
            final firstDay = DateTime(focusedMonth.year, focusedMonth.month, 1);
            final startingWeekday = firstDay.weekday; // 1=Mon, 7=Sun

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setModalState(() {
                            focusedMonth = DateTime(focusedMonth.year, focusedMonth.month - 1);
                          });
                        },
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(focusedMonth),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setModalState(() {
                            focusedMonth = DateTime(focusedMonth.year, focusedMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Legend
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Present / Approved', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('Absent / Pending', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Days of week header (Sat & Sun grayed out)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: const [
                          Text('Mon', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          Text('Tue', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          Text('Wed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          Text('Thu', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          Text('Fri', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          Text('Sat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1))),
                          Text('Sun', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFCBD5E1))),
                        ],
                      ),
                      const Divider(height: 12),

                      // Month Calendar Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: daysInMonth + (startingWeekday - 1),
                        itemBuilder: (context, index) {
                          if (index < startingWeekday - 1) {
                            return const SizedBox();
                          }
                          final dayNum = index - (startingWeekday - 2);
                          final date = DateTime(focusedMonth.year, focusedMonth.month, dayNum);
                          final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
                          final isFuture = date.isAfter(DateTime.now());

                          if (isWeekend) {
                            return Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$dayNum',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                              ),
                            );
                          }

                          final isOk = _isDateApprovedOrAttended(date);
                          final isSelected = _attendanceDate != null &&
                              _attendanceDate!.year == date.year &&
                              _attendanceDate!.month == date.month &&
                              _attendanceDate!.day == date.day;
                          final dotColor = isOk ? const Color(0xFF10B981) : const Color(0xFFEF4444);

                          return InkWell(
                            onTap: isFuture
                                ? null
                                : () {
                                    setState(() {
                                      _attendanceDate = date;
                                    });
                                    Navigator.pop(ctx);
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFDC2626)
                                    : isOk
                                        ? const Color(0xFFECFDF5)
                                        : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFDC2626)
                                      : isOk
                                          ? const Color(0xFFA7F3D0)
                                          : const Color(0xFFFECACA),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '$dayNum',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white : dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _selectTime(bool isCheckIn) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isCheckIn
          ? (_checkInTime ?? const TimeOfDay(hour: 8, minute: 0))
          : (_checkOutTime ?? const TimeOfDay(hour: 17, minute: 0)),
    );
    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = picked;
        } else {
          _checkOutTime = picked;
        }
      });
    }
  }

  void _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_attendanceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select attendance date to correct')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_attendanceDate!);
      final checkInStr = _checkInTime != null
          ? '$dateStr ${_checkInTime!.hour.toString().padLeft(2, '0')}:${_checkInTime!.minute.toString().padLeft(2, '0')}'
          : '';
      final checkOutStr = _checkOutTime != null
          ? '$dateStr ${_checkOutTime!.hour.toString().padLeft(2, '0')}:${_checkOutTime!.minute.toString().padLeft(2, '0')}'
          : '';

      await ApiService.submitCorrection(
        attendanceDate: dateStr,
        correctedCheckIn: checkInStr,
        correctedCheckOut: checkOutStr,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance correction request submitted successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Attendance Correction Form', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Attendance Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),

              // DatePicker Button displaying Selected Date & Status Dot
              InkWell(
                onTap: _selectDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (_attendanceDate != null)
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _isDateApprovedOrAttended(_attendanceDate!)
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _attendanceDate == null
                                ? 'Select Attendance Date'
                                : DateFormat('EEEE, dd MMMM yyyy').format(_attendanceDate!),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const Icon(Icons.calendar_month_rounded, size: 20, color: Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Check-In Time (Correction)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectTime(true),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              _checkInTime == null ? 'Select Time' : _checkInTime!.format(context),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Check-Out Time (Correction)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _selectTime(false),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              _checkOutTime == null ? 'Select Time' : _checkOutTime!.format(context),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Reason for Correction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                validator: (val) => val == null || val.isEmpty ? 'Reason is required' : null,
                decoration: InputDecoration(
                  hintText: 'Describe issue (e.g. forgot check-in / network connection error)...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    disabledBackgroundColor: const Color(0xFFDC2626).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Correction Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
