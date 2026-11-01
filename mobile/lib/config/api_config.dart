import 'package:flutter/foundation.dart';

class ApiConfig {
  // Flag to toggle between local Go backend (port 8080) and production VPS
  static bool useLocalBackend = true;

  /// Optional build-time override, e.g.
  /// `flutter run --dart-define=API_BASE_URL=https://staging.example.com/api/v1`
  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (useLocalBackend) {
      return 'http://localhost:8080/api/v1';
    }
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

  static String get announcements => '$baseUrl/announcements';

  static String get myBadges => '$baseUrl/badges/me';
  static String get timeline => '$baseUrl/timeline';

  /// Server-relative media paths (/api/v1/media/...) → absolute URL.
  static String mediaUrl(String path) {
    if (path.isEmpty || path.startsWith('http')) return path;
    final base = baseUrl;
    final root = base.endsWith('/api/v1') ? base.substring(0, base.length - '/api/v1'.length) : base;
    return '$root$path';
  }
  static String get badgesSeen => '$baseUrl/badges/seen';
}
