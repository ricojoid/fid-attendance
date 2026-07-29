import 'package:flutter/foundation.dart';

class ApiConfig {
  // Use http://localhost:8080/api/v1 for Web (Chrome) & Desktop, or 10.0.2.2 for Android emulator
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080/api/v1';
    }
    return 'http://10.0.2.2:8080/api/v1';
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
