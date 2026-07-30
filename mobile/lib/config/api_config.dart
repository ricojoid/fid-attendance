import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return '/api/v1';
    }
    return 'https://attendance.ocir-dev.my.id/api/v1';
  }

  static String get login => '$baseUrl/auth/login';
  static String get getMe => '$baseUrl/auth/me';

  static String get todayAttendance => '$baseUrl/attendance/today';
  static String get checkIn => '$baseUrl/attendance/check-in';
  static String get checkOut => '$baseUrl/attendance/check-out';
  static String get attendanceHistory => '$baseUrl/attendance/history';

  static String get leaveTypes => '$baseUrl/leave/types';
  static String get submitLeave => '$baseUrl/leave/request';
  static String get leaveHistory => '$baseUrl/leave/history';

  static String get submitCorrection => '$baseUrl/attendance/correction';
  static String get correctionHistory => '$baseUrl/attendance/correction/history';
}
