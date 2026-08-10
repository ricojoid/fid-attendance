import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class AttendanceLogScreen extends StatefulWidget {
  const AttendanceLogScreen({super.key});

  @override
  State<AttendanceLogScreen> createState() => _AttendanceLogScreenState();
}

class _AttendanceLogScreenState extends State<AttendanceLogScreen> {
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final attendanceList = await ApiService.getAttendanceHistory();
      final correctionList = await ApiService.getCorrectionHistory();

      Map<String, Map<String, dynamic>> combinedMap = {};

      // 1. Process regular attendance check-in logs
      if (attendanceList is List) {
        for (var a in attendanceList) {
          if (a is Map) {
            final dateStr = (a['date'] ?? '').toString();
            if (dateStr.isNotEmpty) {
              combinedMap[dateStr] = {
                'date': dateStr,
                'check_in_time': a['check_in_time'],
                'check_out_time': a['check_out_time'],
                'source': 'ATTENDANCE',
              };
            }
          }
        }
      }

      // 2. Process APPROVED attendance correction requests
      if (correctionList is List) {
        for (var c in correctionList) {
          if (c is Map && (c['status'] ?? '').toString().toUpperCase() == 'APPROVED') {
            final dateStr = (c['attendance_date'] ?? '').toString();
            if (dateStr.isNotEmpty) {
              final checkIn = c['corrected_check_in'] ?? c['check_in_time'];
              final checkOut = c['corrected_check_out'] ?? c['check_out_time'];

              final existingIn = combinedMap[dateStr]?['check_in_time'];
              final existingOut = combinedMap[dateStr]?['check_out_time'];

              combinedMap[dateStr] = {
                'date': dateStr,
                'check_in_time': checkIn ?? existingIn,
                'check_out_time': checkOut ?? existingOut,
                'source': 'APPROVED_CORRECTION',
              };
            }
          }
        }
      }

      // 3. Convert map values to list and sort by date descending
      final result = combinedMap.values.toList();
      result.sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

      setState(() {
        _logs = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load attendance logs: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(dynamic value) {
    if (value == null) return '--:--';
    final str = value.toString().trim();
    if (str.isEmpty || str == 'null') return '--:--';

    if (str.length == 5 && str.contains(':')) return str;
    if (str.contains(' ') && !str.contains('T')) {
      final parts = str.split(' ');
      if (parts.length >= 2 && parts[1].contains(':')) {
        final timePart = parts[1];
        return timePart.length >= 5 ? timePart.substring(0, 5) : timePart;
      }
    }

    try {
      final dt = DateTime.parse(str);
      return DateFormat('HH:mm').format(dt.toLocal());
    } catch (_) {
      return str.length >= 5 ? str.substring(0, 5) : str;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEEE, dd MMMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Attendance Log',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.history_rounded, size: 48, color: Color(0xFF94A3B8)),
                      SizedBox(height: 12),
                      Text('No attendance records found', style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _logs[index];
                      final dateStr = item['date'] ?? '';
                      final checkIn = item['check_in_time'];
                      final checkOut = item['check_out_time'];
                      final isApprovedCorrection = item['source'] == 'APPROVED_CORRECTION';

                      return TweenAnimationBuilder<double>(
                        key: ValueKey('log_${item['date']}_$index'),
                        duration: Duration(milliseconds: 300 + (index * 45).clamp(0, 450).toInt()),
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        builder: (context, animValue, child) {
                          return Transform.translate(
                            offset: Offset(0, 16 * (1 - animValue)),
                            child: Opacity(
                              opacity: animValue,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x05000000),
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date & Approved Badge Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(dateStr),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isApprovedCorrection)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFA7F3D0)),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                                          SizedBox(width: 4),
                                          Text(
                                            'Approved Correction',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1, color: Color(0xFFF1F5F9)),
                              const SizedBox(height: 12),

                              // Check In & Check Out Times
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.login_rounded, size: 20, color: Color(0xFF10B981)),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Check In', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatTime(checkIn),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFFEF4444)),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Check Out', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 2),
                                            Text(
                                              _formatTime(checkOut),
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                            ),
                                          ],
                                        ),
                                      ],
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
    );
  }
}
