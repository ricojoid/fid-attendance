import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static final ValueNotifier<String?> profilePhotoNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int> inboxBadgeNotifier = ValueNotifier<int>(0);

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    profilePhotoNotifier.value = null;
  }

  static Future<String?> getProfilePhoto([String? userKey]) async {
    final prefs = await SharedPreferences.getInstance();
    if (userKey != null && userKey.isNotEmpty) {
      final userPhoto = prefs.getString('profile_photo_$userKey');
      if (userPhoto != null && userPhoto.isNotEmpty) return userPhoto;
    }
    // Do NOT fallback to generic 'profile_photo' — each user has their own key
    return null;
  }

  static Future<void> saveProfilePhoto(String pathOrUrl, [String? userKey]) async {
    final prefs = await SharedPreferences.getInstance();
    if (userKey != null && userKey.isNotEmpty) {
      // Save only to user-specific key — never overwrite the generic shared key
      await prefs.setString('profile_photo_$userKey', pathOrUrl);
    }
    profilePhotoNotifier.value = pathOrUrl;

    // Persist to server DB so other users can view this profile photo
    try {
      final headers = await _getHeaders();
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/profile'),
        headers: headers,
        body: jsonEncode({'avatar_url': pathOrUrl}),
      );
    } catch (e) {
      debugPrint('Failed to sync avatar_url to DB: $e');
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Auth
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.body.trim().isEmpty) {
        throw Exception('Server returned an empty response (${response.statusCode}). Please ensure backend is running.');
      }

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (e) {
        throw Exception('Failed to parse server response (${response.statusCode}). Please ensure backend is running at ${ApiConfig.baseUrl}');
      }

      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        await saveToken(data['token']);
        final user = data['user'];
        final userEmail = (user?['email'] ?? email).toString();
        final photo = await getProfilePhoto(userEmail);
        profilePhotoNotifier.value = photo;
        return data;
      } else {
        final errMsg = (data is Map && data['error'] != null)
            ? data['error'].toString()
            : 'Login failed (Status ${response.statusCode})';
        throw Exception(errMsg);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get Current Profile
  static Future<Map<String, dynamic>> getMe() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(ApiConfig.getMe), headers: headers);
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        if (data['user'] is Map<String, dynamic>) {
          return data['user'] as Map<String, dynamic>;
        }
        return data;
      }
    } catch (e) {
      debugPrint('Error in getMe: $e');
    }
    return {};
  }

  // Today Attendance
  static Future<Map<String, dynamic>> getTodayAttendance() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(ApiConfig.todayAttendance), headers: headers);
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    } catch (e) {
      debugPrint('Error in getTodayAttendance: $e');
    }
    return {};
  }

  // Check In
  static Future<Map<String, dynamic>> checkIn(double lat, double long, String address) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(ApiConfig.checkIn),
      headers: headers,
      body: jsonEncode({
        'lat': lat,
        'long': long,
        'address': address,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Check-in failed');
    }
  }

  // Check Out
  static Future<Map<String, dynamic>> checkOut(double lat, double long, String address) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(ApiConfig.checkOut),
      headers: headers,
      body: jsonEncode({
        'lat': lat,
        'long': long,
        'address': address,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Check-out failed');
    }
  }

  // Leave Types & Submit Leave
  static Future<List<dynamic>> getLeaveTypes() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(ApiConfig.leaveTypes), headers: headers);
      return _parseList(response.body);
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> submitLeave({
    required int leaveTypeId,
    required String startDate,
    required String endDate,
    required String reason,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(ApiConfig.submitLeave),
      headers: headers,
      body: jsonEncode({
        'leave_type_id': leaveTypeId,
        'start_date': startDate,
        'end_date': endDate,
        'reason': reason,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Failed to submit leave request');
    }
  }

  // Attendance Correction
  static Future<Map<String, dynamic>> submitCorrection({
    required String attendanceDate,
    required String correctedCheckIn,
    required String correctedCheckOut,
    required String reason,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(ApiConfig.submitCorrection),
      headers: headers,
      body: jsonEncode({
        'attendance_date': attendanceDate,
        'corrected_check_in': correctedCheckIn,
        'corrected_check_out': correctedCheckOut,
        'reason': reason,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 201) {
      return data;
    } else {
      throw Exception(data['error'] ?? 'Failed to submit correction request');
    }
  }

  static List<dynamic> _parseList(dynamic body) {
    try {
      final decoded = jsonDecode(body.toString());
      if (decoded is List) {
        return decoded;
      }
      if (decoded is Map && decoded['data'] is List) {
        return decoded['data'] as List;
      }
    } catch (_) {}
    return [];
  }

  // History & Admin Endpoints
  static Future<List<dynamic>> getAttendanceHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(ApiConfig.attendanceHistory), headers: headers);
      return _parseList(response.body);
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> getLeaveHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(ApiConfig.leaveHistory), headers: headers);
      return _parseList(response.body);
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> getCorrectionHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(ApiConfig.correctionHistory), headers: headers);
      return _parseList(response.body);
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> getAllUsers() async {
    try {
      final headers = await _getHeaders();
      var response = await http.get(Uri.parse('${ApiConfig.baseUrl}/users'), headers: headers);
      if (response.statusCode != 200) {
        response = await http.get(Uri.parse('${ApiConfig.baseUrl}/admin/users'), headers: headers);
      }
      return _parseList(response.body);
    } catch (e) {
      debugPrint('Failed to fetch users: $e');
      return [];
    }
  }

  // Real Backend Approval & Notification endpoints
  static Future<List<dynamic>> getPendingApprovals() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/approval/pending'), headers: headers);
      final list = _parseList(response.body);
      return list;
    } catch (e) {
      debugPrint('Failed to fetch pending approvals: $e');
      return [];
    }
  }

  static Future<int> refreshInboxCount() async {
    try {
      final notifications = await getNotifications();
      final approvals = await getPendingApprovals();

      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_notif_ids') ?? [];

      int unreadNotifs = 0;
      for (var n in notifications) {
        if (n is Map) {
          final idStr = n['id']?.toString() ?? '';
          final status = (n['status'] ?? '').toString().toUpperCase();
          final isRead = n['is_read'] == true || status == 'READ' || readIds.contains(idStr) || readIds.contains('db_notif_$idStr');
          if (!isRead) {
            unreadNotifs++;
          }
        }
      }

      int pendingApprovalsCount = approvals.where((e) => e is Map && e['status'] == 'PENDING').length;

      int totalBadge = unreadNotifs + pendingApprovalsCount;
      inboxBadgeNotifier.value = totalBadge;
      return totalBadge;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> markSingleNotificationAsRead(String idStr) async {
    try {
      final headers = await _getHeaders();
      final cleanId = idStr.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleanId.isNotEmpty) {
        await http.put(Uri.parse('${ApiConfig.baseUrl}/notifications/read/$cleanId'), headers: headers);
      }

      final prefs = await SharedPreferences.getInstance();
      final readIds = prefs.getStringList('read_notif_ids') ?? [];
      if (!readIds.contains(idStr)) {
        readIds.add(idStr);
      }
      if (cleanId.isNotEmpty && !readIds.contains(cleanId)) {
        readIds.add(cleanId);
      }
      await prefs.setStringList('read_notif_ids', readIds);
      await refreshInboxCount();
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  static Future<void> markAllNotificationsAsRead() async {
    try {
      final headers = await _getHeaders();
      await http.put(Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'), headers: headers);

      final notifications = await getNotifications();
      final prefs = await SharedPreferences.getInstance();
      final existingReadIds = prefs.getStringList('read_notif_ids') ?? [];
      final Set<String> readSet = Set.from(existingReadIds);

      for (var n in notifications) {
        if (n is Map && n['id'] != null) {
          readSet.add(n['id'].toString());
          readSet.add('db_notif_${n['id']}');
        }
      }
      await prefs.setStringList('read_notif_ids', readSet.toList());
      await refreshInboxCount();
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  static Future<Map<String, dynamic>> processApproval(String category, dynamic id, String status) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/approval/process'),
        headers: headers,
        body: jsonEncode({
          'type': category,
          'id': id is int ? id : int.tryParse(id.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 1,
          'status': status,
        }),
      );
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (e) {
      debugPrint('Error processing approval: $e');
    }
    return {'message': 'Approval processed'};
  }

  static Future<List<dynamic>> getNotifications() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/notifications'), headers: headers);
      return _parseList(response.body);
    } catch (e) {
      debugPrint('Failed to fetch notifications: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getAnnouncements() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse(ApiConfig.announcements), headers: headers);
      return _parseList(response.body);
    } catch (e) {
      debugPrint('Failed to fetch announcements: $e');
      return [];
    }
  }
}

