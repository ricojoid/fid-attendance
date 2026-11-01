import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/badge.dart';
import 'live_events.dart';

class ApiService {
  static final ValueNotifier<String?> profilePhotoNotifier = ValueNotifier<String?>(null);
  static final ValueNotifier<int> inboxBadgeNotifier = ValueNotifier<int>(0);

  /// Active app theme code (LIGHT, DARK, SAKURA, …).
  static final ValueNotifier<String> themeNotifier = ValueNotifier<String>('LIGHT');

  static Future<void> _applyTheme(String code) async {
    if (code.isEmpty) code = 'LIGHT';
    themeNotifier.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_theme', code);
  }

  static Future<String> loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('app_theme') ?? 'LIGHT';
    themeNotifier.value = code;
    return code;
  }

  static Future<Map<String, dynamic>> getMyThemes() async {
    final response = await _client.get(Uri.parse('${ApiConfig.baseUrl}/themes/me'), headers: await _getHeaders()).timeout(_timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data is Map) return data.cast<String, dynamic>();
    throw Exception((data is Map ? data['error'] : null) ?? 'Failed to load themes');
  }

  static Future<void> equipTheme(String code) async {
    final response = await _client
        .put(Uri.parse('${ApiConfig.baseUrl}/themes/equip'), headers: await _getHeaders(), body: jsonEncode({'code': code}))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception((data is Map ? data['error'] : null) ?? 'Failed to apply theme');
    }
    if (_meCache != null) _meCache!['app_theme'] = code;
    await _applyTheme(code);
  }

  /// Currently equipped avatar frame code ('' = none).
  static final ValueNotifier<String> frameNotifier = ValueNotifier<String>('');

  /// Bumped when someone's profile data (e.g. photo) changes so lists refetch.
  static final ValueNotifier<int> teamChangedNotifier = ValueNotifier<int>(0);

  /// Latest badge summary, shared by Home, Badges and Account screens.
  static final ValueNotifier<BadgeSummary> badgesNotifier = ValueNotifier<BadgeSummary>(BadgeSummary.empty);

  // One pooled client = keep-alive connections instead of a new TCP/TLS
  // handshake for every request.
  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 15);

  // Token is read from disk once, then served from memory.
  static String? _token;
  static bool _tokenLoaded = false;

  // getMe() is requested by several screens at start-up: cache + de-duplicate.
  static Map<String, dynamic>? _meCache;
  static DateTime? _meCachedAt;
  static Future<Map<String, dynamic>>? _meInFlight;
  static const Duration _meTtl = Duration(minutes: 2);

  static Future<String?> getToken() async {
    if (_tokenLoaded) return _token;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _tokenLoaded = true;
    return _token;
  }

  static Future<void> saveToken(String token) async {
    _token = token;
    _tokenLoaded = true;
    invalidateMe();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
    await prefs.setString(_refreshedAtKey, DateTime.now().toIso8601String());
  }

  static Future<void> removeToken() async {
    LiveEvents.stop();
    _token = null;
    _tokenLoaded = true;
    invalidateMe();
    badgesNotifier.value = BadgeSummary.empty;
    frameNotifier.value = '';
    await _applyTheme('LIGHT');
    inboxBadgeNotifier.value = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    profilePhotoNotifier.value = null;
  }

  /// Fires when the server rejects the session (30 days without opening the app).
  static final ValueNotifier<int> sessionExpiredNotifier = ValueNotifier<int>(0);

  static const _refreshedAtKey = 'jwt_refreshed_at';
  static const Duration _refreshEvery = Duration(hours: 6);
  static Future<bool>? _refreshInFlight;

  /// Slides the 30-day session forward. Called on start-up and whenever the
  /// app returns to the foreground, so active users are never logged out.
  /// Returns false only when the server says the session is gone (401).
  static Future<bool> refreshSession({bool force = false}) {
    return _refreshInFlight ??= _doRefresh(force).whenComplete(() => _refreshInFlight = null);
  }

  static Future<bool> _doRefresh(bool force) async {
    final token = await getToken();
    if (token == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final last = DateTime.tryParse(prefs.getString(_refreshedAtKey) ?? '');
    if (!force && last != null && DateTime.now().difference(last) < _refreshEvery) return true;
    try {
      final response = await _client
          .post(Uri.parse('${ApiConfig.baseUrl}/auth/refresh'), headers: await _getHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['token'] is String) {
          _token = data['token'] as String;
          await prefs.setString('jwt_token', _token!);
          await prefs.setString(_refreshedAtKey, DateTime.now().toIso8601String());
        }
        return true;
      }
      if (response.statusCode == 401) {
        await removeToken();
        sessionExpiredNotifier.value++;
        return false;
      }
    } catch (e) {
      // Offline / server down: keep the user signed in and retry later.
      debugPrint('Session refresh skipped: $e');
    }
    return true;
  }

  static Map<String, dynamic>? _approverCache;

  /// Who receives this user's leave/correction requests.
  static Future<Map<String, dynamic>?> getMyApprover() async {
    if (_approverCache != null) return _approverCache;
    try {
      final response = await _client
          .get(Uri.parse('${ApiConfig.baseUrl}/approval/my-approver'), headers: await _getHeaders())
          .timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['approver'] is Map) {
          _approverCache = (data['approver'] as Map).cast<String, dynamic>();
          return _approverCache;
        }
      }
    } catch (e) {
      debugPrint('Error in getMyApprover: $e');
    }
    return null;
  }

  static void invalidateMe() {
    _approverCache = null;
    _meCache = null;
    _meCachedAt = null;
    _meInFlight = null;
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
      final res = await _client
          .put(
            Uri.parse('${ApiConfig.baseUrl}/profile'),
            headers: headers,
            body: jsonEncode({'avatar_url': pathOrUrl}),
          )
          .timeout(const Duration(seconds: 30));
      invalidateMe();
      if (res.statusCode != 200) {
        throw Exception('Server rejected the photo (${res.statusCode})');
      }
      teamChangedNotifier.value++;
    } catch (e) {
      debugPrint('Failed to sync avatar_url to DB: $e');
      // Surface the failure: otherwise colleagues never see the new photo
      // while this device happily shows it.
      rethrow;
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
      final response = await _client.post(
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

  // Get Current Profile (cached for [_meTtl]; concurrent callers share one request)
  static Future<Map<String, dynamic>> getMe({bool forceRefresh = false}) {
    final fresh = _meCache != null && _meCachedAt != null && DateTime.now().difference(_meCachedAt!) < _meTtl;
    if (!forceRefresh && fresh) return Future.value(_meCache!);
    if (!forceRefresh && _meInFlight != null) return _meInFlight!;
    final future = _fetchMe();
    _meInFlight = future;
    return future;
  }

  static Future<Map<String, dynamic>> _fetchMe() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse(ApiConfig.getMe), headers: headers).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data is Map<String, dynamic>) {
        final user = data['user'] is Map<String, dynamic> ? data['user'] as Map<String, dynamic> : data;
        _meCache = user;
        _meCachedAt = DateTime.now();
        frameNotifier.value = (user['avatar_frame'] ?? '').toString();
        final serverTheme = (user['app_theme'] ?? '').toString();
        if (serverTheme.isNotEmpty && serverTheme != themeNotifier.value) _applyTheme(serverTheme);
        // The server photo is the source of truth (it may have been changed
        // from the web dashboard): push it to every listening widget.
        final serverPhoto = (user['avatar_url'] ?? '').toString();
        if (serverPhoto.isNotEmpty && serverPhoto != profilePhotoNotifier.value) {
          profilePhotoNotifier.value = serverPhoto;
          final email = (user['email'] ?? '').toString();
          if (email.isNotEmpty) {
            SharedPreferences.getInstance().then((p) => p.setString('profile_photo_$email', serverPhoto));
          }
        }
        return user;
      }
    } catch (e) {
      debugPrint('Error in getMe: $e');
    } finally {
      _meInFlight = null;
    }
    return _meCache ?? {};
  }

  // Achievement badges
  static Future<BadgeSummary> getMyBadges() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse(ApiConfig.myBadges), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) {
          final summary = BadgeSummary.fromJson(data.cast<String, dynamic>());
          badgesNotifier.value = summary;
          return summary;
        }
      }
    } catch (e) {
      debugPrint('Error in getMyBadges: $e');
    }
    return badgesNotifier.value;
  }

  static Future<BadgeSummary?> getUserBadges(dynamic userId) async {
    try {
      final headers = await _getHeaders();
      final response =
          await _client.get(Uri.parse('${ApiConfig.baseUrl}/badges/user/$userId'), headers: headers).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map) return BadgeSummary.fromJson(data.cast<String, dynamic>());
      }
    } catch (e) {
      debugPrint('Error in getUserBadges: $e');
    }
    return null;
  }

  // Avatar frames
  static Future<Map<String, dynamic>> getMyFrames() async {
    final response = await _client.get(Uri.parse('${ApiConfig.baseUrl}/frames/me'), headers: await _getHeaders()).timeout(_timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data is Map) return data.cast<String, dynamic>();
    throw Exception((data is Map ? data['error'] : null) ?? 'Failed to load frames');
  }

  static Future<void> equipFrame(String code) async {
    final response = await _client
        .put(Uri.parse('${ApiConfig.baseUrl}/frames/equip'), headers: await _getHeaders(), body: jsonEncode({'code': code}))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception((data is Map ? data['error'] : null) ?? 'Failed to equip frame');
    }
    frameNotifier.value = code;
    if (_meCache != null) _meCache!['avatar_frame'] = code;
    teamChangedNotifier.value++;
  }

  /// Choose which badge colleagues see next to your name ('' = automatic).
  static Future<void> featureBadge(String code) async {
    final response = await _client
        .put(Uri.parse('${ApiConfig.baseUrl}/badges/feature'), headers: await _getHeaders(), body: jsonEncode({'code': code}))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception((data is Map ? data['error'] : null) ?? 'Failed to update');
    }
    teamChangedNotifier.value++;
    await getMyBadges();
  }

  // ---------------------------------------------------------------- Timeline
  static Future<Map<String, dynamic>> getTimeline({int? before}) async {
    final uri = Uri.parse(ApiConfig.timeline).replace(queryParameters: {'limit': '15', if (before != null) 'before': '$before'});
    final response = await _client.get(uri, headers: await _getHeaders()).timeout(_timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data is Map) return data.cast<String, dynamic>();
    throw Exception((data is Map ? data['error'] : null) ?? 'Failed to load timeline');
  }

  static Future<Map<String, dynamic>> createPost({required String text, List<int>? imageBytes, String? filename, int? w, int? h}) async {
    final req = http.MultipartRequest('POST', Uri.parse('${ApiConfig.timeline}/posts'));
    final token = await getToken();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['text'] = text;
    if (imageBytes != null) {
      req.files.add(http.MultipartFile.fromBytes('image', imageBytes, filename: filename ?? 'photo.jpg'));
      if (w != null) req.fields['image_w'] = '$w';
      if (h != null) req.fields['image_h'] = '$h';
    }
    final streamed = await _client.send(req).timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    final data = jsonDecode(body);
    if (streamed.statusCode == 201 && data is Map) return data.cast<String, dynamic>();
    throw Exception((data is Map ? data['error'] : null) ?? 'Failed to publish');
  }

  static Future<Map<String, dynamic>> toggleLike(int postId) async {
    final response = await _client.post(Uri.parse('${ApiConfig.timeline}/posts/$postId/like'), headers: await _getHeaders()).timeout(_timeout);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> getComments(int postId) async {
    final response = await _client.get(Uri.parse('${ApiConfig.timeline}/posts/$postId/comments'), headers: await _getHeaders()).timeout(_timeout);
    return (jsonDecode(response.body) as Map).cast<String, dynamic>();
  }

  static Future<Map<String, dynamic>> addComment(int postId, String text) async {
    final response = await _client
        .post(Uri.parse('${ApiConfig.timeline}/posts/$postId/comments'), headers: await _getHeaders(), body: jsonEncode({'text': text}))
        .timeout(_timeout);
    final data = jsonDecode(response.body);
    if (response.statusCode == 201 && data is Map) return data.cast<String, dynamic>();
    throw Exception((data is Map ? data['error'] : null) ?? 'Failed to comment');
  }

  static Future<void> deletePost(int postId) async {
    final response = await _client.delete(Uri.parse('${ApiConfig.timeline}/posts/$postId'), headers: await _getHeaders()).timeout(_timeout);
    if (response.statusCode != 200) {
      final data = jsonDecode(response.body);
      throw Exception((data is Map ? data['error'] : null) ?? 'Failed to delete');
    }
  }

  static Future<void> markBadgesSeen(List<String> codes) async {
    try {
      final headers = await _getHeaders();
      await _client
          .post(Uri.parse(ApiConfig.badgesSeen), headers: headers, body: jsonEncode({'codes': codes}))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('Error in markBadgesSeen: $e');
    }
  }

  // Today Attendance
  static Future<Map<String, dynamic>> getTodayAttendance() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse(ApiConfig.todayAttendance), headers: headers);
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
    } catch (e) {
      debugPrint('Error in getTodayAttendance: $e');
    }
    return {};
  }

  // Check In
  static Future<Map<String, dynamic>> checkIn(double lat, double long, String address,
      {double? accuracy, String? note}) async {
    final headers = await _getHeaders();
    final response = await _client.post(
      Uri.parse(ApiConfig.checkIn),
      headers: headers,
      body: jsonEncode({
        'lat': lat,
        'long': long,
        'address': address,
        if (accuracy != null) 'accuracy': accuracy,
        if (note != null && note.isNotEmpty) 'note': note,
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
  static Future<Map<String, dynamic>> checkOut(double lat, double long, String address,
      {double? accuracy, String? note}) async {
    final headers = await _getHeaders();
    final response = await _client.post(
      Uri.parse(ApiConfig.checkOut),
      headers: headers,
      body: jsonEncode({
        'lat': lat,
        'long': long,
        'address': address,
        if (accuracy != null) 'accuracy': accuracy,
        if (note != null && note.isNotEmpty) 'note': note,
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
      final response = await _client.get(Uri.parse(ApiConfig.leaveTypes), headers: headers);
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
    final response = await _client.post(
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
    final response = await _client.post(
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
      final response = await _client.get(Uri.parse(ApiConfig.attendanceHistory), headers: headers);
      return _parseList(response.body);
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> getLeaveHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse(ApiConfig.leaveHistory), headers: headers);
      return _parseList(response.body);
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> getCorrectionHistory() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse(ApiConfig.correctionHistory), headers: headers);
      return _parseList(response.body);
    } catch (_) {
      return [];
    }
  }

  static Future<List<dynamic>> getAllUsers() async {
    try {
      final headers = await _getHeaders();
      var response = await _client.get(Uri.parse('${ApiConfig.baseUrl}/users'), headers: headers);
      if (response.statusCode != 200) {
        response = await _client.get(Uri.parse('${ApiConfig.baseUrl}/admin/users'), headers: headers);
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
      final response = await _client.get(Uri.parse('${ApiConfig.baseUrl}/approval/pending'), headers: headers);
      final list = _parseList(response.body);
      return list;
    } catch (e) {
      debugPrint('Failed to fetch pending approvals: $e');
      return [];
    }
  }

  static Future<int> refreshInboxCount() async {
    try {
      // Fetch both in parallel instead of back-to-back.
      final results = await Future.wait([getNotifications(), getPendingApprovals()]);
      final notifications = results[0];
      final approvals = results[1];

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
        await _client.put(Uri.parse('${ApiConfig.baseUrl}/notifications/read/$cleanId'), headers: headers);
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
      await _client.put(Uri.parse('${ApiConfig.baseUrl}/notifications/read-all'), headers: headers);

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
      final response = await _client.post(
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
      final response = await _client.get(Uri.parse('${ApiConfig.baseUrl}/notifications'), headers: headers);
      return _parseList(response.body);
    } catch (e) {
      debugPrint('Failed to fetch notifications: $e');
      return [];
    }
  }

  static Future<List<dynamic>> getAnnouncements() async {
    try {
      final headers = await _getHeaders();
      final response = await _client.get(Uri.parse(ApiConfig.announcements), headers: headers);
      return _parseList(response.body);
    } catch (e) {
      debugPrint('Failed to fetch announcements: $e');
      return [];
    }
  }
}

