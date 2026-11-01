import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../models/badge.dart';
import '../services/api_service.dart';
import '../services/live_events.dart';
import '../theme/app_theme.dart';
import '../utils/avatar_cache.dart';
import '../widgets/aurora_background.dart';
import '../widgets/avatar_frame.dart';
import '../widgets/badge_medal.dart';
import '../widgets/celebration.dart';
import '../widgets/motion.dart';
import '../widgets/streak_flame.dart';
import 'attendance_log_screen.dart';
import 'attendance_success_screen.dart';
import 'badges_screen.dart';
import 'calendar_screen.dart';
import 'inbox_screen.dart';
import 'leave_request_screen.dart';

/// Shift rules shared with the backend badge engine.
const Duration kShiftSpan = Duration(hours: 9); // 8h work + 1h break
const Duration kBreak = Duration(hours: 1);

DateTime? parseAttendanceTime(dynamic value) {
  if (value == null) return null;
  final str = value.toString().trim();
  if (str.isEmpty || str == 'null') return null;
  final dt = DateTime.tryParse(str);
  if (dt != null) return dt.toLocal();
  if (str.contains(':')) {
    final parts = str.split(':');
    final now = DateTime.now();
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h != null && m != null) return DateTime(now.year, now.month, now.day, h, m);
  }
  return null;
}

String formatDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;
  Map<String, dynamic>? _todayAttendance;
  String _userName = '';
  String? _profilePhotoPath;
  List<dynamic> _announcements = [];
  bool _celebrating = false;

  double? _currentLat;
  double? _currentLong;
  double? _currentAccuracy;
  String _currentAddress = 'Fetching location...';

  @override
  void initState() {
    super.initState();
    ApiService.profilePhotoNotifier.addListener(_onPhotoChanged);
    LiveEvents.announcements.addListener(_onAnnouncements);
    _fetchTodayData();
    _determinePosition();
  }

  @override
  void dispose() {
    ApiService.profilePhotoNotifier.removeListener(_onPhotoChanged);
    LiveEvents.announcements.removeListener(_onAnnouncements);
    super.dispose();
  }

  /// Announcements pushed live by the server appear instantly.
  void _onAnnouncements() {
    if (mounted) setState(() => _announcements = LiveEvents.announcements.value);
  }

  void _onPhotoChanged() {
    final v = ApiService.profilePhotoNotifier.value;
    if (mounted && v != _profilePhotoPath) setState(() => _profilePhotoPath = v);
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 17) return 'Good afternoon';
    if (hour >= 17 && hour < 21) return 'Good evening';
    return 'Good night';
  }

  Future<void> _fetchTodayData() async {
    try {
      // All independent requests run in parallel (previously sequential).
      final results = await Future.wait<dynamic>([
        ApiService.getTodayAttendance(),
        ApiService.getAnnouncements(),
        ApiService.getMe(),
        ApiService.getMyBadges(),
      ]);
      final res = results[0] as Map<String, dynamic>;
      final anns = results[1] as List<dynamic>;
      final profile = results[2] as Map<String, dynamic>;
      final badges = results[3] as BadgeSummary;
      final serverPhoto = (profile['avatar_url'] ?? '').toString();
      final savedPhoto = serverPhoto.isNotEmpty ? serverPhoto : await ApiService.getProfilePhoto((profile['email'] ?? '').toString());

      if (!mounted) return;
      setState(() {
        if (profile['name'] != null) _userName = profile['name'].toString();
        _hasCheckedIn = res['has_checked_in'] ?? false;
        _hasCheckedOut = res['has_checked_out'] ?? false;
        _todayAttendance = res['data'] is Map<String, dynamic> ? res['data'] : null;
        _profilePhotoPath = savedPhoto;
        _announcements = anns;
        LiveEvents.announcements.value = anns.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      });
      _maybeCelebrate(badges);
    } catch (e) {
      debugPrint('Error fetching today attendance: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _maybeCelebrate(BadgeSummary badges) async {
    if (_celebrating || badges.newlyUnlocked.isEmpty || !mounted) return;
    // Only celebrate when Home is the visible tab.
    if (!TickerMode.valuesOf(context).enabled) return;
    _celebrating = true;
    await showBadgeUnlocked(context, badges.newlyUnlocked);
    await ApiService.markBadgesSeen(badges.newlyUnlocked.map((b) => b.code).toList());
    _celebrating = false;
    ApiService.getMyBadges();
  }

  String _fmtTime(dynamic value) {
    final dt = parseAttendanceTime(value);
    return dt == null ? '--:--' : DateFormat('HH:mm').format(dt);
  }

  Future<void> _determinePosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _currentAddress = 'Location services disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _currentAddress = 'Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _currentAddress = 'Location permission permanently denied');
        return;
      }

      // Show the last known fix instantly, then refine with a fresh one.
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _currentLat = last.latitude;
        _currentLong = last.longitude;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 12),
      );
      _currentLat = position.latitude;
      _currentLong = position.longitude;
      _currentAccuracy = position.accuracy;

      try {
        final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks[0];
          setState(() {
            // Full, detailed address for the admin location map.
            final parts = <String>[];
            for (final p in [
              place.name,
              place.street,
              place.subLocality,
              place.locality,
              place.subAdministrativeArea,
              place.administrativeArea,
              place.postalCode,
            ]) {
              final v = (p ?? '').trim();
              if (v.isNotEmpty && !parts.contains(v)) parts.add(v);
            }
            _currentAddress = parts.join(', ');
          });
        }
      } catch (_) {
        // Reverse-geocoding failed but we do have coordinates.
        if (mounted) {
          setState(() => _currentAddress = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _currentAddress = 'Location unavailable — tap to retry');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Dialogs & sheets
  // ---------------------------------------------------------------------------

  void _showMapDialog(BuildContext context) {
    final point = LatLng(_currentLat ?? -6.2088, _currentLong ?? 106.8456);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 280,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(initialCenter: point, initialZoom: 16),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.fid_attendance_mobile',
                      ),
                      MarkerLayer(markers: [
                        Marker(point: point, width: 64, height: 64, child: const _PulsingPin()),
                      ]),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Pressable(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, boxShadow: AppShadows.soft),
                        child: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.redSoft, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.location_on_rounded, color: AppColors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DETECTED LOCATION',
                            style: TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.textFaint, letterSpacing: 1)),
                        const SizedBox(height: 3),
                        Text(_currentAddress, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncementDialog(String title, String tag, String date, String content) {
    final style = _AnnStyle.of(tag);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
        padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(gradient: style.gradient, borderRadius: BorderRadius.circular(14)),
                    child: Icon(style.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(tag, style: TextStyle(color: style.color, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 12)),
                  const Spacer(),
                  Text(date, style: TextStyle(color: AppColors.textFaint, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4, height: 1.25)),
              const SizedBox(height: 12),
              Text(content, style: TextStyle(fontSize: 14.5, color: AppColors.textMuted, height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }

  void _openAttendanceBottomSheet(bool isCheckIn) {
    if (_currentLat == null || _currentLong == null) _determinePosition();

    final notesController = TextEditingController();
    XFile? pickedSelfie;
    bool isSubmittingModal = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final typeText = isCheckIn ? 'Check-In' : 'Check-Out';
            final gradient = isCheckIn ? AppGradients.brand : AppGradients.checkout;
            final primaryColor = isCheckIn ? AppColors.red : AppColors.success;

            Future<void> pickSelfie() async {
              final picker = ImagePicker();
              try {
                final photo = await picker.pickImage(
                  source: ImageSource.camera,
                  preferredCameraDevice: CameraDevice.front,
                  imageQuality: 70,
                  maxWidth: 1080,
                );
                if (photo != null) setModalState(() => pickedSelfie = photo);
              } catch (_) {
                try {
                  final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 1080);
                  if (image != null) setModalState(() => pickedSelfie = image);
                } catch (err) {
                  debugPrint('Failed to pick selfie: $err');
                }
              }
            }

            Future<void> submitAttendance() async {
              final notesText = notesController.text.trim();
              if (notesText.isEmpty) {
                setModalState(() => modalError = 'Attendance note is required. Please enter your note.');
                return;
              }

              setModalState(() {
                isSubmittingModal = true;
                modalError = null;
              });

              // Never record a made-up position: get a real GPS fix first.
              if (_currentLat == null || _currentLong == null) await _determinePosition();
              if (_currentLat == null || _currentLong == null) {
                setModalState(() {
                  isSubmittingModal = false;
                  modalError = 'Location unavailable. Please turn on GPS / allow location access and try again.';
                });
                return;
              }

              try {
                final now = DateTime.now();
                if (isCheckIn) {
                  await ApiService.checkIn(_currentLat!, _currentLong!, _currentAddress,
                      accuracy: _currentAccuracy, note: notesText);
                } else {
                  await ApiService.checkOut(_currentLat!, _currentLong!, _currentAddress,
                      accuracy: _currentAccuracy, note: notesText);
                }

                if (!mounted || !bottomSheetContext.mounted) return;
                Navigator.pop(bottomSheetContext);

                await Navigator.push(
                  this.context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceSuccessScreen(
                      isCheckIn: isCheckIn,
                      timestamp: now,
                      address: _currentAddress,
                      notes: notesText,
                      imageFile: pickedSelfie,
                    ),
                  ),
                );
                if (mounted) _fetchTodayData();
              } catch (e) {
                setModalState(() => modalError = e.toString().replaceAll('Exception: ', ''));
              } finally {
                if (bottomSheetContext.mounted) setModalState(() => isSubmittingModal = false);
              }
            }

            final hasNoteError = modalError != null && notesController.text.trim().isEmpty;

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: Container(
                decoration: BoxDecoration(color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                ),
                padding: EdgeInsets.fromLTRB(22, 12, 22, 22 + MediaQuery.paddingOf(context).bottom),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 5,
                          decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: gradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppShadows.glow(primaryColor, strength: 0.3),
                            ),
                            child: Icon(isCheckIn ? Icons.login_rounded : Icons.logout_rounded, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(typeText,
                                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                                Text(DateFormat('EEEE, d MMM · HH:mm').format(DateTime.now()),
                                    style:
                                        TextStyle(color: AppColors.textMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Location
                      Pressable(
                        pressedScale: 0.98,
                        onTap: () => _showMapDialog(context),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 36, height: 36, child: _PulsingPin(small: true)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Your location',
                                        style: TextStyle(fontSize: 11, color: AppColors.textFaint, fontWeight: FontWeight.w700)),
                                    Text(_currentAddress,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              Text('Map',
                                  style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800, fontSize: 12.5)),
                              Icon(Icons.chevron_right_rounded, color: AppColors.red, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          const Text('Attendance note', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                          Text(' *', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          if (hasNoteError)
                            Text('Required',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.red)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        textCapitalization: TextCapitalization.sentences,
                        onChanged: (_) {
                          if (modalError != null) setModalState(() => modalError = null);
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g. Working from office / WFH / Client meeting',
                          enabledBorder: hasNoteError
                              ? OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.red))
                              : null,
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: primaryColor, width: 1.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ['Working from office', 'WFH', 'Client visit', 'Business trip'].map((s) {
                          return Pressable(
                            onTap: () => setModalState(() {
                              notesController.text = s;
                              modalError = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                              ),
                              child: Text(s, style: TextStyle(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 12)),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      const Text('Selfie (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Pressable(
                        pressedScale: 0.98,
                        onTap: pickSelfie,
                        child: AnimatedContainer(
                          duration: AppMotion.medium,
                          curve: AppMotion.emphasized,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: pickedSelfie != null ? AppColors.success.withValues(alpha: 0.07) : const Color(0xFFF8F9FC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: pickedSelfie != null ? AppColors.success.withValues(alpha: 0.4) : AppColors.line,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(pickedSelfie != null ? Icons.check_circle_rounded : Icons.photo_camera_front_rounded,
                                  color: pickedSelfie != null ? AppColors.success : AppColors.textMuted),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  pickedSelfie != null ? 'Selfie attached' : 'Take a selfie / attach photo',
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(pickedSelfie != null ? 'Change' : 'Open camera',
                                  style: TextStyle(color: primaryColor, fontSize: 12.5, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),

                      AnimatedSize(
                        duration: AppMotion.medium,
                        curve: AppMotion.emphasized,
                        child: modalError == null
                            ? const SizedBox(width: double.infinity)
                            : Container(
                                margin: const EdgeInsets.only(top: 14),
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.redSoft,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(modalError!,
                                          style: TextStyle(
                                              color: AppColors.redDeep, fontSize: 12.5, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),

                      _GradientButton(
                        gradient: gradient,
                        glow: primaryColor,
                        loading: isSubmittingModal,
                        label: 'Confirm $typeText',
                        icon: isCheckIn ? Icons.fingerprint_rounded : Icons.logout_rounded,
                        onTap: isSubmittingModal ? null : submitAttendance,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(notesController.dispose);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final checkIn = parseAttendanceTime(_todayAttendance?['check_in_time']);
    final checkOut = parseAttendanceTime(_todayAttendance?['check_out_time']);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: RefreshIndicator(
        color: AppColors.red,
        edgeOffset: MediaQuery.paddingOf(context).top,
        onRefresh: () async {
          ApiService.invalidateMe();
          await Future.wait([_fetchTodayData(), _determinePosition()]);
        },
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHero(
                greeting: _getGreeting(),
                name: _userName,
                photo: _profilePhotoPath,
                hasCheckedIn: _hasCheckedIn,
                hasCheckedOut: _hasCheckedOut,
                checkIn: checkIn,
                checkOut: checkOut,
                checkInLabel: _fmtTime(_todayAttendance?['check_in_time']),
                checkOutLabel: _fmtTime(_todayAttendance?['check_out_time']),
                loading: _isLoading,
                onStreakTap: _openBadges,
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                child: _isLoading
                    ? const Shimmer(height: 130, radius: 28)
                    : AnimatedSwitcher(
                        duration: AppMotion.slow,
                        switchInCurve: AppMotion.emphasized,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
                        ),
                        child: _hasCheckedOut
                            ? _CompletedCard(key: const ValueKey('done'), checkIn: checkIn, checkOut: checkOut)
                            : _AttendanceOrb(
                                key: ValueKey(_hasCheckedIn),
                                isCheckIn: !_hasCheckedIn,
                                address: _currentAddress,
                                onTap: () => _openAttendanceBottomSheet(!_hasCheckedIn),
                                onLocationTap: () {
                                  setState(() => _currentAddress = 'Fetching location...');
                                  _determinePosition();
                                },
                              ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: FadeSlideIn(delay: const Duration(milliseconds: 120), child: _BadgeStrip(onTap: _openBadges)),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: _QuickActions(onBadges: _openBadges),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
                child: Row(
                  children: [
                    const Text('Announcements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const Spacer(),
                    if (_announcements.isNotEmpty)
                      Text('${math.min(3, _announcements.length)} latest',
                          style: TextStyle(color: AppColors.textFaint, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ),
            if (_announcements.isEmpty)
              const SliverToBoxAdapter(child: _EmptyAnnouncements())
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: math.min(3, _announcements.length),
                  itemBuilder: (context, i) {
                    final ann = _announcements[i];
                    final title = ann['title']?.toString() ?? 'Announcement';
                    final category = ann['category']?.toString() ?? 'GENERAL';
                    final content = ann['content']?.toString() ?? '';
                    final created = DateTime.tryParse(ann['created_at']?.toString() ?? '');
                    final date = created != null ? DateFormat('d MMM yyyy').format(created.toLocal()) : '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      key: ValueKey('ann_${ann['id']}'),
                      child: FadeSlideIn.stagger(
                        i,
                        baseMs: 260,
                        child: _AnnouncementCard(
                          title: title,
                          category: category,
                          date: date,
                          content: content,
                          onTap: () => _showAnnouncementDialog(title, category, date, content),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  void _openBadges() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BadgesScreen()));
  }
}

// =============================================================================
// Hero
// =============================================================================

class _HomeHero extends StatelessWidget {
  final String greeting, name;
  final String? photo;
  final bool hasCheckedIn, hasCheckedOut, loading;
  final DateTime? checkIn, checkOut;
  final String checkInLabel, checkOutLabel;
  final VoidCallback onStreakTap;

  const _HomeHero({
    required this.greeting,
    required this.name,
    required this.photo,
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    required this.checkIn,
    required this.checkOut,
    required this.checkInLabel,
    required this.checkOutLabel,
    required this.loading,
    required this.onStreakTap,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final status = hasCheckedOut ? 'Shift complete' : (hasCheckedIn ? 'On shift' : 'Not checked in');
    final statusColor = hasCheckedOut ? const Color(0xFF34D399) : (hasCheckedIn ? AppColors.amber : Colors.white70);

    return AuroraBackground(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 12, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(photo: photo, name: name),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$greeting 👋',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(name.isEmpty ? ' ' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: -0.4)),
                        ],
                      ),
                    ),
                    _StreakChip(onTap: onStreakTap),
                    const SizedBox(width: 8),
                    const _InboxBell(),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _LiveClock(),
                          const SizedBox(height: 4),
                          Text(DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12.5, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: AppMotion.medium,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _BlinkDot(color: statusColor, blink: hasCheckedIn && !hasCheckedOut),
                                const SizedBox(width: 6),
                                Text(status, style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w800)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _ShiftRing(checkIn: checkIn, checkOut: checkOut, size: 118),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TimeTile(
                        label: 'CHECK IN',
                        value: checkInLabel,
                        hint: hasCheckedIn ? 'Recorded' : 'Target 08:00',
                        icon: Icons.login_rounded,
                        done: hasCheckedIn,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimeTile(
                        label: 'CHECK OUT',
                        value: checkOutLabel,
                        hint: hasCheckedOut
                            ? 'Recorded'
                            : (checkIn != null
                                ? 'Earliest ${DateFormat('HH:mm').format(checkIn!.add(kShiftSpan))}'
                                : 'Target 17:00'),
                        icon: Icons.logout_rounded,
                        done: hasCheckedOut,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photo;
  final String name;
  const _Avatar({required this.photo, required this.name});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: ApiService.profilePhotoNotifier,
      builder: (context, notifierPhoto, _) => ValueListenableBuilder<String>(
        valueListenable: ApiService.frameNotifier,
        builder: (context, frame, _) {
          final p = (notifierPhoto != null && notifierPhoto.isNotEmpty) ? notifierPhoto : photo;
          if (kFrameStyles.containsKey(frame)) {
            return FramedAvatar(frame: frame, photo: p, name: name, size: 44);
          }
          final img = AvatarCache.provider(p);
          return Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(colors: [AppColors.amber, AppColors.red, AppColors.magenta, AppColors.amber]),
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.ink),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.red,
                backgroundImage: img,
                child: img == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18))
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Inbox (notifications + approvals) lives behind a bell with a live count.
class _InboxBell extends StatelessWidget {
  const _InboxBell();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ApiService.inboxBadgeNotifier,
      builder: (context, count, _) => Pressable(
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxScreen()));
          ApiService.refreshInboxCount();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.notifications_rounded, color: Colors.white, size: 20),
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(count),
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.ink, width: 1.5),
                    ),
                    child: Text(count > 99 ? '99+' : '$count',
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  final VoidCallback onTap;
  const _StreakChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BadgeSummary>(
      valueListenable: ApiService.badgesNotifier,
      builder: (context, s, _) {
        final streak = s.stats.currentStreak;
        final lit = streak > 0 && s.stats.streakAliveToday;
        return Pressable(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
            decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StreakFlame(size: 20, lit: lit),
                const SizedBox(width: 6),
                AnimatedCount(
                  value: streak,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ticks once per second but only rebuilds itself, and skips rebuilds while
/// its tab is hidden (TickerMode disabled).
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hm = DateFormat('HH:mm').format(_now);
    final ss = DateFormat('ss').format(_now);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(hm,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 46,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              fontFeatures: [FontFeature.tabularFigures()],
            )),
        const SizedBox(width: 4),
        Text(ss,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}

class _BlinkDot extends StatefulWidget {
  final Color color;
  final bool blink;
  const _BlinkDot({required this.color, required this.blink});

  @override
  State<_BlinkDot> createState() => _BlinkDotState();
}

class _BlinkDotState extends State<_BlinkDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _BlinkDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.blink && !reduceMotion(context)) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.3, end: 1.0).animate(_c),
      child: Container(width: 7, height: 7, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label, value, hint;
  final IconData icon;
  final bool done;

  const _TimeTile({required this.label, required this.value, required this.hint, required this.icon, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: AppMotion.medium,
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: done ? const Color(0xFF34D399).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(done ? Icons.check_rounded : icon, color: done ? const Color(0xFF34D399) : Colors.white70, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                AnimatedSwitcher(
                  duration: AppMotion.medium,
                  child: Text(value,
                      key: ValueKey(value),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                ),
                Text(hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 10.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ring showing time on site against the 9h shift (8h work + 1h break).
/// Past 9h the ring keeps going in violet to visualise overtime.
class _ShiftRing extends StatefulWidget {
  final DateTime? checkIn, checkOut;
  final double size;
  const _ShiftRing({required this.checkIn, required this.checkOut, this.size = 118});

  @override
  State<_ShiftRing> createState() => _ShiftRingState();
}

class _ShiftRingState extends State<_ShiftRing> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant _ShiftRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer();
  }

  void _syncTimer() {
    final live = widget.checkIn != null && widget.checkOut == null;
    if (live && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted && TickerMode.valuesOf(context).enabled) setState(() {});
      });
    } else if (!live) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inT = widget.checkIn;
    final span = inT == null ? Duration.zero : (widget.checkOut ?? DateTime.now()).difference(inT);
    final ratio = span.inSeconds / kShiftSpan.inSeconds;
    final over = span > kShiftSpan;
    final work = span - kBreak;

    return SizedBox.square(
      dimension: widget.size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: ratio.clamp(0.0, 2.0)),
        duration: const Duration(milliseconds: 1400),
        curve: AppMotion.emphasized,
        builder: (context, v, _) {
          return CustomPaint(
            painter: _RingPainter(v),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inT == null ? '0h' : formatDuration(span),
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    inT == null
                        ? 'of 9h shift'
                        : over
                            ? '+${formatDuration(span - kShiftSpan)} OT'
                            : '${formatDuration(work.isNegative ? Duration.zero : work)} work',
                    style: TextStyle(
                      color: over ? const Color(0xFFC4B5FD) : Colors.white.withValues(alpha: 0.6),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value; // 1.0 == 9h; >1 is overtime
  const _RingPainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: size.width / 2 - stroke / 2);
    const start = -math.pi / 2;

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.12),
    );

    // Break marker at 8/9 of the ring ("work done" point).
    const markA = start + 2 * math.pi * (8 / 9);
    canvas.drawArc(
      rect,
      markA - 0.015,
      0.03,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 1.25
        ..color = Colors.white.withValues(alpha: 0.35),
    );

    final main = value.clamp(0.0, 1.0);
    if (main > 0) {
      canvas.drawArc(
        rect,
        start,
        2 * math.pi * main,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke
          ..shader = SweepGradient(
            colors: [AppColors.amber, AppColors.coral, const Color(0xFF34D399)],
            transform: const GradientRotation(-math.pi / 2),
          ).createShader(rect),
      );
    }
    final ot = (value - 1).clamp(0.0, 1.0);
    if (ot > 0) {
      canvas.drawArc(
        rect.deflate(stroke * 1.2),
        start,
        2 * math.pi * ot,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke * 0.6
          ..color = const Color(0xFFA78BFA),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

// =============================================================================
// Main action
// =============================================================================

/// Simple, friendly primary action: "slide to check in / out".
/// One pill, one thumb. Sliding prevents accidental check-ins; a tap on the
/// thumb works too. Only the label shimmer animates (single controller).
class _AttendanceOrb extends StatefulWidget {
  final bool isCheckIn;
  final String address;
  final VoidCallback onTap;
  final VoidCallback onLocationTap;

  const _AttendanceOrb({
    super.key,
    required this.isCheckIn,
    required this.address,
    required this.onTap,
    required this.onLocationTap,
  });

  @override
  State<_AttendanceOrb> createState() => _AttendanceOrbState();
}

class _AttendanceOrbState extends State<_AttendanceOrb> with TickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  late final AnimationController _thumb = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  double _drag = 0; // 0..1
  double _backFrom = 0;
  bool _dragging = false;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _thumb.addListener(() {
      if (!_dragging) setState(() => _drag = _backFrom * (1 - Curves.easeOutBack.transform(_thumb.value)).clamp(0.0, 1.0));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _shine.stop();
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    _thumb.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_fired) return;
    _fired = true;
    HapticFeedback.mediumImpact();
    setState(() => _drag = 1);
    await Future.delayed(const Duration(milliseconds: 180));
    widget.onTap();
    // Spring back once the sheet is up.
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    _animateBack();
    _fired = false;
  }

  void _animateBack() {
    _backFrom = _drag;
    _thumb.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final checkIn = widget.isCheckIn;
    final color = checkIn ? AppColors.red : AppColors.success;
    final gradient = checkIn ? AppGradients.brand : AppGradients.checkout;
    final label = checkIn ? 'Slide to check in' : 'Slide to check out';
    const h = 68.0, pad = 6.0;

    return Column(
      children: [
        Row(
          children: [
            Text(checkIn ? 'Ready to start your day?' : 'Wrapping up for today?',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: -0.2)),
            const Spacer(),
            Text(checkIn ? '☀️' : '🌙', style: const TextStyle(fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final travel = c.maxWidth - h;
          final x = travel * _drag;
          return Container(
            height: h,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(h / 2),
              boxShadow: AppShadows.glow(color, strength: 0.35),
            ),
            child: Stack(
              children: [
                // Progress fill behind the thumb.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: x + h,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: AppColors.surface.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(h / 2),
                    ),
                  ),
                ),
                // Shimmering label + chevrons (fade out as you slide).
                Positioned.fill(
                  child: Opacity(
                    opacity: (1 - _drag * 1.6).clamp(0.0, 1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(left: h * 0.6),
                      child: Center(
                        child: RepaintBoundary(
                          child: AnimatedBuilder(
                            animation: _shine,
                            builder: (context, child) => ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (r) => LinearGradient(
                                begin: Alignment(-1.0 + _shine.value * 3 - 0.5, 0),
                                end: Alignment(-1.0 + _shine.value * 3 + 0.5, 0),
                                colors: [
                                  Colors.white.withValues(alpha: 0.65),
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.65)
                                ],
                              ).createShader(r),
                              child: child,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.2)),
                                const SizedBox(width: 6),
                                const Icon(Icons.keyboard_double_arrow_right_rounded, color: Colors.white, size: 22),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Thumb.
                Positioned(
                  left: x + pad,
                  top: pad,
                  child: GestureDetector(
                    onTap: _complete,
                    onHorizontalDragStart: (_) {
                      _thumb.stop();
                      setState(() => _dragging = true);
                    },
                    onHorizontalDragUpdate: (d) {
                      setState(() => _drag = (_drag + d.delta.dx / travel).clamp(0.0, 1.0));
                      if (_drag >= 0.98) _complete();
                    },
                    onHorizontalDragEnd: (_) {
                      _dragging = false;
                      if (_drag > 0.8) {
                        _complete();
                      } else {
                        _animateBack();
                      }
                    },
                    child: Container(
                      width: h - pad * 2,
                      height: h - pad * 2,
                      decoration: BoxDecoration(color: AppColors.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.text.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4))
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: Icon(
                          _drag > 0.8 ? Icons.check_rounded : (checkIn ? Icons.fingerprint_rounded : Icons.logout_rounded),
                          key: ValueKey(_drag > 0.8),
                          color: color,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onLocationTap,
          child: Row(
            children: [
              Icon(Icons.my_location_rounded, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(widget.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              Icon(Icons.refresh_rounded, size: 14, color: AppColors.textFaint),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final DateTime? checkIn, checkOut;
  const _CompletedCard({super.key, required this.checkIn, required this.checkOut});

  @override
  Widget build(BuildContext context) {
    final span = (checkIn != null && checkOut != null) ? checkOut!.difference(checkIn!) : Duration.zero;
    final work = span - kBreak;
    final overtime = span > kShiftSpan;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFECFDF5), Colors.white],
        ),
        border: Border.all(color: const Color(0xFFA7F3D0)),
        boxShadow: AppShadows.glow(AppColors.success, strength: 0.12),
      ),
      child: Column(
        children: [
          const _DrawnCheck(size: 84),
          const SizedBox(height: 14),
          const Text('Shift complete — great work!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
          const SizedBox(height: 4),
          Text('See you tomorrow. Your attendance is safely recorded.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 18),
          Row(
            children: [
              _MiniStat(label: 'On site', value: formatDuration(span), color: AppColors.info),
              const SizedBox(width: 10),
              _MiniStat(label: 'Work (−1h break)', value: formatDuration(work), color: AppColors.success),
              const SizedBox(width: 10),
              _MiniStat(
                label: 'Overtime',
                value: overtime ? '+${formatDuration(span - kShiftSpan)}' : '—',
                color: AppColors.overtime,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final LinearGradient gradient;
  final Color glow;
  final bool loading;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.gradient,
    required this.glow,
    required this.loading,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      pressedScale: 0.97,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: onTap == null && !loading ? 0.6 : 1,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: AppShadows.glow(glow, strength: 0.35),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.fast,
              child: loading
                  ? const SizedBox(
                      key: ValueKey('l'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                    )
                  : Row(
                      key: const ValueKey('t'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Check mark that draws itself once.
class _DrawnCheck extends StatelessWidget {
  final double size;
  const _DrawnCheck({required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Transform.scale(
        scale: 0.6 + 0.4 * Curves.elasticOut.transform(v.clamp(0.0, 1.0)),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.checkout,
            boxShadow: AppShadows.glow(AppColors.success),
          ),
          child: CustomPaint(painter: _CheckPainter(v)),
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double t;
  const _CheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.73, size.height * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.t != t;
}

class _PulsingPin extends StatefulWidget {
  final bool small;
  const _PulsingPin({this.small = false});

  @override
  State<_PulsingPin> createState() => _PulsingPinState();
}

class _PulsingPinState extends State<_PulsingPin> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.small ? 36.0 : 64.0;
    return RepaintBoundary(
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Container(
              width: s * (0.4 + 0.6 * _c.value),
              height: s * (0.4 + 0.6 * _c.value),
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.red.withValues(alpha: 0.35 * (1 - _c.value))),
            ),
          ),
          Container(
            width: s * 0.42,
            height: s * 0.42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.brand,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(Icons.person_rounded, color: Colors.white, size: s * 0.24),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Badges, quick actions, announcements
// =============================================================================

class _BadgeStrip extends StatelessWidget {
  final VoidCallback onTap;
  const _BadgeStrip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BadgeSummary>(
      valueListenable: ApiService.badgesNotifier,
      builder: (context, s, _) {
        final next = s.nextFor('STREAK') ?? s.nextFor('OVERTIME');
        return Pressable(
          pressedScale: 0.98,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              gradient: AppGradients.ink,
              boxShadow: AppShadows.glow(AppColors.ink, strength: 0.25),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: AppColors.amber, size: 20),
                    const SizedBox(width: 8),
                    const Text('Achievements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                    const Spacer(),
                    Text('${s.earnedCount}/${s.badges.isEmpty ? 8 : s.badges.length}',
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, fontSize: 12.5)),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white54),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 70,
                  child: s.isEmpty
                      ? Row(
                          children: List.generate(
                            4,
                            (i) => const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Opacity(opacity: 0.15, child: Shimmer(height: 62, width: 62, radius: 31)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: s.badges.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => BadgeMedal(badge: s.badges[i], size: 70, showProgress: false),
                        ),
                ),
                if (next != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Next: ${next.name} · ${next.remaining} ${next.isStreak ? 'weekdays' : 'overtime days'} to go',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text('${(next.percent * 100).round()}%',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: next.percent),
                      duration: const Duration(milliseconds: 1200),
                      curve: AppMotion.emphasized,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        backgroundColor: AppColors.surface.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation(next.isStreak ? const Color(0xFFFF7A1A) : const Color(0xFFA78BFA)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onBadges;
  const _QuickActions({required this.onBadges});

  @override
  Widget build(BuildContext context) {
    final items = [
      _QA('History', Icons.receipt_long_rounded, const [Color(0xFF34D399), Color(0xFF059669)],
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceLogScreen()))),
      _QA('Calendar', Icons.calendar_month_rounded, const [Color(0xFF818CF8), Color(0xFF4F46E5)],
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()))),
      _QA('Badges', Icons.military_tech_rounded, const [Color(0xFFFFC94D), Color(0xFFFF7A1A)], onBadges),
      _QA('Leave', Icons.beach_access_rounded, [const Color(0xFFFF8A80), AppColors.red],
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveRequestScreen()))),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick access', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final it in items)
              Expanded(
                child: Pressable(
                  onTap: it.onTap,
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: it.colors),
                          boxShadow: AppShadows.glow(it.colors.last, strength: 0.28),
                        ),
                        child: Stack(
                          children: [
                            // Glossy highlight for a more "app icon" look.
                            Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              height: 28,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
                                  ),
                                ),
                              ),
                            ),
                            Center(child: Icon(it.icon, color: Colors.white, size: 27)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(it.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _QA {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  _QA(this.label, this.icon, this.colors, this.onTap);
}

class _AnnStyle {
  final Color color;
  final LinearGradient gradient;
  final IconData icon;
  const _AnnStyle(this.color, this.gradient, this.icon);

  static _AnnStyle of(String category) {
    switch (category) {
      case 'IMPORTANT':
        return _AnnStyle(AppColors.red, AppGradients.brand, Icons.priority_high_rounded);
      case 'EVENT':
        return const _AnnStyle(
            AppColors.info, LinearGradient(colors: [Color(0xFF818CF8), Color(0xFF4F46E5)]), Icons.celebration_rounded);
      case 'MAINTENANCE':
        return const _AnnStyle(
            AppColors.warning, LinearGradient(colors: [Color(0xFFFCD34D), Color(0xFFD97706)]), Icons.build_rounded);
      default:
        return const _AnnStyle(
            AppColors.success, LinearGradient(colors: [Color(0xFF6EE7B7), Color(0xFF059669)]), Icons.campaign_rounded);
    }
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String title, category, date, content;
  final VoidCallback onTap;

  const _AnnouncementCard({
    required this.title,
    required this.category,
    required this.date,
    required this.content,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = _AnnStyle.of(category);
    return Pressable(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: style.gradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadows.glow(style.color, strength: 0.22),
              ),
              child: Icon(style.icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(category,
                          style: TextStyle(color: style.color, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                      const Spacer(),
                      Text(date, style: TextStyle(color: AppColors.textFaint, fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyAnnouncements extends StatelessWidget {
  const _EmptyAnnouncements();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            Icon(Icons.mark_email_read_rounded, color: AppColors.textFaint, size: 34),
            const SizedBox(height: 8),
            const Text('You are all caught up', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('No announcements yet.', style: TextStyle(color: AppColors.textMuted, fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}
