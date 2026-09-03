import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';
import 'attendance_success_screen.dart';
import 'attendance_log_screen.dart';
import 'calendar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasCheckedIn = false;
  bool _hasCheckedOut = false;
  Map<String, dynamic>? _todayAttendance;
  String _userName = 'Budi Santoso';
  String? _profilePhotoPath;
  List<dynamic> _announcements = [];
  double _contentOpacity = 0.0;

  double? _currentLat;
  double? _currentLong;
  String _currentAddress = 'Fetching location...';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    ApiService.profilePhotoNotifier.addListener(_onPhotoChanged);
    _fetchTodayData();
    _determinePosition();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    ApiService.profilePhotoNotifier.removeListener(_onPhotoChanged);
    super.dispose();
  }

  void _onPhotoChanged() {
    if (mounted) {
      setState(() {
        _profilePhotoPath = ApiService.profilePhotoNotifier.value;
      });
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Good Morning,';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon,';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening,';
    } else {
      return 'Good Night,';
    }
  }

  Future<void> _fetchTodayData() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.getTodayAttendance();
      final anns = await ApiService.getAnnouncements();
      String? savedPhoto;
      try {
        final profile = await ApiService.getMe();
        if (profile != null && profile['name'] != null) {
          _userName = profile['name'];
        }
        final userEmail = profile?['email'] ?? '';
        savedPhoto = await ApiService.getProfilePhoto(userEmail);
      } catch (_) {
        savedPhoto = await ApiService.getProfilePhoto();
      }

      setState(() {
        _hasCheckedIn = res['has_checked_in'] ?? false;
        _hasCheckedOut = res['has_checked_out'] ?? false;
        _todayAttendance = res['data'];
        _profilePhotoPath = savedPhoto;
        _announcements = anns;
      });
    } catch (e) {
      debugPrint('Error fetching today attendance: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _contentOpacity = 1.0;
      });
    }
  }

  String _getFormattedCheckTime(dynamic value) {
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

  String? _getWorkDuration() {
    final inVal = _todayAttendance?['check_in_time'];
    final outVal = _todayAttendance?['check_out_time'];
    if (inVal == null) return null;

    try {
      DateTime inDt;
      final inStr = inVal.toString().trim();
      if (inStr.contains('T') || inStr.contains('-')) {
        inDt = DateTime.parse(inStr).toLocal();
      } else if (inStr.contains(':')) {
        final now = DateTime.now();
        final parts = inStr.split(':');
        inDt = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      } else {
        return null;
      }

      DateTime outDt;
      if (outVal != null) {
        final outStr = outVal.toString().trim();
        if (outStr.contains('T') || outStr.contains('-')) {
          outDt = DateTime.parse(outStr).toLocal();
        } else if (outStr.contains(':')) {
          final now = DateTime.now();
          final parts = outStr.split(':');
          outDt = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
        } else {
          outDt = DateTime.now();
        }
      } else {
        outDt = DateTime.now();
      }

      final diff = outDt.difference(inDt);
      if (diff.isNegative) return null;
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      if (hours == 0 && minutes == 0) return 'Just started';
      if (hours == 0) return '${minutes}m worked';
      return '${hours}h ${minutes}m worked';
    } catch (_) {
      return null;
    }
  }

  ImageProvider? _getProfileImageProvider([String? customPath]) {
    final path = (customPath != null && customPath.isNotEmpty) ? customPath : _profilePhotoPath;
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('data:image')) {
      final base64Str = path.split(',').last;
      return MemoryImage(base64Decode(base64Str));
    } else if (kIsWeb || path.startsWith('http') || path.startsWith('blob:')) {
      return NetworkImage(path);
    } else {
      return FileImage(File(path));
    }
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _currentAddress = 'Location services disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _currentAddress = 'Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _currentAddress = 'Location permission permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLat = position.latitude;
      _currentLong = position.longitude;

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            _currentAddress = '${place.street}, ${place.subLocality}, ${place.locality}';
          });
        }
      } catch (e) {
        setState(() {
          _currentAddress = 'Jakarta, Indonesia';
        });
      }
    } catch (e) {
      setState(() {
        _currentAddress = 'Jakarta, Indonesia';
        _currentLat = -6.2088;
        _currentLong = 106.8456;
      });
    }
  }

  void _showMapDialog(BuildContext context) {
    final lat = _currentLat ?? -6.2088;
    final long = _currentLong ?? 106.8456;
    final point = LatLng(lat, long);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.map_rounded, color: Color(0xFFDC2626)),
                      SizedBox(width: 8),
                      Text(
                        'Location Map',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Interactive OpenStreetMap Container
              Container(
                height: 250,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 15.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.fid_attendance_mobile',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 60,
                          height: 60,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
                                  ],
                                ),
                                child: const Icon(Icons.person_pin_circle, color: Colors.white, size: 24),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detected Address:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currentAddress,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnnouncementDialog(String title, String tag, String date, String content) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tag == 'IMPORTANT'
                          ? const Color(0xFFFEF2F2)
                          : tag == 'EVENT'
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tag == 'IMPORTANT'
                            ? const Color(0xFFEF4444)
                            : tag == 'EVENT'
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF10B981),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 16),
              Text(
                content,
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569), height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close Announcement', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard({
    required String title,
    required String category,
    required String date,
    required String snippet,
    required String content,
  }) {
    Color tagBg = const Color(0xFFFEE2E2);
    Color tagColor = const Color(0xFFDC2626);
    Color accentBorder = const Color(0xFFDC2626);

    if (category == 'IMPORTANT') {
      tagBg = const Color(0xFFFEF2F2);
      tagColor = const Color(0xFFEF4444);
      accentBorder = const Color(0xFFEF4444);
    } else if (category == 'EVENT') {
      tagBg = const Color(0xFFEEF2FF);
      tagColor = const Color(0xFF6366F1);
      accentBorder = const Color(0xFF6366F1);
    } else if (category == 'MAINTENANCE') {
      tagBg = const Color(0xFFFEF3C7);
      tagColor = const Color(0xFFD97706);
      accentBorder = const Color(0xFFD97706);
    } else if (category == 'POLICY' || category == 'GENERAL') {
      tagBg = const Color(0xFFECFDF5);
      tagColor = const Color(0xFF10B981);
      accentBorder = const Color(0xFF10B981);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF64748B).withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _showAnnouncementDialog(title, category, date, content),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Vertical Color Bar Accent
                Container(
                  width: 4,
                  height: 52,
                  decoration: BoxDecoration(
                    color: accentBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: tagBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagColor),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        snippet,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAttendanceBottomSheet(bool isCheckIn) {
    if (_currentLat == null || _currentLong == null) {
      _determinePosition();
    }

    final notesController = TextEditingController();
    XFile? pickedSelfie;
    bool isSubmittingModal = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final typeText = isCheckIn ? 'Check-In' : 'Check-Out';
            final primaryColor = isCheckIn ? const Color(0xFFDC2626) : const Color(0xFF10B981);

            Future<void> pickSelfie() async {
              try {
                final picker = ImagePicker();
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  preferredCameraDevice: CameraDevice.front,
                  imageQuality: 70,
                );
                if (photo != null) {
                  setModalState(() {
                    pickedSelfie = photo;
                  });
                }
              } catch (e) {
                try {
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setModalState(() {
                      pickedSelfie = image;
                    });
                  }
                } catch (err) {
                  debugPrint('Failed to pick selfie: $err');
                }
              }
            }

            Future<void> submitAttendance() async {
              final notesText = notesController.text.trim();
              if (notesText.isEmpty) {
                setModalState(() {
                  modalError = 'Attendance note is required. Please enter your note.';
                });
                return;
              }

              setModalState(() {
                isSubmittingModal = true;
                modalError = null;
              });

              try {
                final now = DateTime.now();
                if (isCheckIn) {
                  await ApiService.checkIn(
                    _currentLat ?? -6.2088,
                    _currentLong ?? 106.8456,
                    _currentAddress,
                  );
                } else {
                  await ApiService.checkOut(
                    _currentLat ?? -6.2088,
                    _currentLong ?? 106.8456,
                    _currentAddress,
                  );
                }

                if (mounted) {
                  Navigator.pop(bottomSheetContext); // Close Bottom Sheet

                  // Navigate to Success Screen
                  final refreshNeeded = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AttendanceSuccessScreen(
                        isCheckIn: isCheckIn,
                        timestamp: now,
                        address: _currentAddress,
                        notes: notesController.text.trim(),
                        imageFile: pickedSelfie,
                      ),
                    ),
                  );

                  if (refreshNeeded == true) {
                    _fetchTodayData();
                  }
                }
              } catch (e) {
                setModalState(() {
                  modalError = e.toString().replaceAll('Exception: ', '');
                });
              } finally {
                setModalState(() => isSubmittingModal = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle Bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFCBD5E1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Header Title
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$typeText Attendance',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Location Button (Full-width like Selfie button)
                      const Text(
                        'Location Map (Optional View)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _showMapDialog(context),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 20),
                              SizedBox(width: 8),
                              Text(
                                'View Location',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes Input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attendance Notes (Required) *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          if (modalError != null && notesController.text.trim().isEmpty)
                            const Text(
                              'Required',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: notesController,
                        onChanged: (_) {
                          if (modalError != null) {
                            setModalState(() => modalError = null);
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g., Working from Office / WFH / Client Meeting',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: (modalError != null && notesController.text.trim().isEmpty)
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: (modalError != null && notesController.text.trim().isEmpty)
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: (modalError != null && notesController.text.trim().isEmpty)
                                  ? const Color(0xFFDC2626)
                                  : primaryColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Optional Take a Selfie Section
                      const Text(
                        'Selfie Photo (Optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: pickSelfie,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: pickedSelfie != null
                              ? Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Selfie Photo Attached (${pickedSelfie!.name})',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Text('Change', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt_rounded, color: Color(0xFFDC2626), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Take a Selfie / Attach Photo',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // In-Modal Error Banner
                      if (modalError != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  modalError!,
                                  style: const TextStyle(
                                    color: Color(0xFFB91C1C),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setModalState(() => modalError = null),
                                child: const Icon(Icons.close_rounded, color: Color(0xFF991B1B), size: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),

                      // Confirm Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: isSubmittingModal ? null : submitAttendance,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: isSubmittingModal
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Text(
                                  'Confirm $typeText',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceCompletedCard() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            const _AnimatedAttendanceCompletedBadge(),
            const SizedBox(height: 16),
            const Text(
              'Attendance Completed for Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Thank you for your hard work and dedication today.\nThe attendance button will be available again tomorrow.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nowStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
            : RefreshIndicator(
                onRefresh: () async {
                  await _fetchTodayData();
                  await _determinePosition();
                },
                child: AnimatedOpacity(
                  opacity: _contentOpacity,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutCubic,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      // User Greeting & Profile Avatar Header
                      Row(
                        children: [
                          Stack(
                            children: [
                              ValueListenableBuilder<String?>(
                                valueListenable: ApiService.profilePhotoNotifier,
                                builder: (context, photoNotifierValue, _) {
                                  final currentPhoto = (photoNotifierValue != null && photoNotifierValue.isNotEmpty)
                                      ? photoNotifierValue
                                      : _profilePhotoPath;
                                  final imageProvider = _getProfileImageProvider(currentPhoto);
                                  return Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFDC2626).withOpacity(0.25),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 26,
                                      backgroundColor: const Color(0xFFDC2626),
                                      backgroundImage: imageProvider,
                                      child: (currentPhoto == null || currentPhoto.isEmpty)
                                          ? Text(
                                              _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            )
                                          : null,
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _userName,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Header Date & Attendance Status Banner Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFF991B1B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      nowStr,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _hasCheckedIn ? const Color(0xFF34D399) : Colors.white70,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _hasCheckedOut ? 'FINISHED' : (_hasCheckedIn ? 'CHECKED IN' : 'PENDING'),
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Dual Check In / Check Out Executive Dashboard Cards
                            Row(
                              children: [
                                // Check In Card
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Subtle Watermark Icon in background to eliminate empty feeling
                                        Positioned(
                                          right: -4,
                                          bottom: -6,
                                          child: Icon(
                                            Icons.login_rounded,
                                            size: 42,
                                            color: Colors.white.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'CHECK IN',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.8),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _hasCheckedIn
                                                        ? const Color(0xFF10B981).withValues(alpha: 0.28)
                                                        : Colors.white.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 5,
                                                        height: 5,
                                                        decoration: BoxDecoration(
                                                          color: _hasCheckedIn ? const Color(0xFF34D399) : Colors.white60,
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _hasCheckedIn ? 'Recorded' : 'Expected',
                                                        style: TextStyle(
                                                          color: _hasCheckedIn ? const Color(0xFF34D399) : Colors.white70,
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.baseline,
                                              textBaseline: TextBaseline.alphabetic,
                                              children: [
                                                Text(
                                                  _getFormattedCheckTime(_todayAttendance?['check_in_time']),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                if (_hasCheckedIn) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'WIB',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.65),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _hasCheckedIn ? 'Shift In • On-site' : 'Target: 08:00 WIB',
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.65),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Check Out Card
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.16),
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Subtle Watermark Icon in background to eliminate empty feeling
                                        Positioned(
                                          right: -4,
                                          bottom: -6,
                                          child: Icon(
                                            Icons.logout_rounded,
                                            size: 42,
                                            color: Colors.white.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'CHECK OUT',
                                                  style: TextStyle(
                                                    color: Colors.white.withValues(alpha: 0.8),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.8,
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: _hasCheckedOut
                                                        ? const Color(0xFF10B981).withValues(alpha: 0.28)
                                                        : (_hasCheckedIn
                                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.28)
                                                            : Colors.white.withValues(alpha: 0.12)),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Container(
                                                        width: 5,
                                                        height: 5,
                                                        decoration: BoxDecoration(
                                                          color: _hasCheckedOut
                                                              ? const Color(0xFF34D399)
                                                              : (_hasCheckedIn ? const Color(0xFFFBBF24) : Colors.white60),
                                                          shape: BoxShape.circle,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        _hasCheckedOut
                                                            ? 'Recorded'
                                                            : (_hasCheckedIn ? 'Working' : 'Pending'),
                                                        style: TextStyle(
                                                          color: _hasCheckedOut
                                                              ? const Color(0xFF34D399)
                                                              : (_hasCheckedIn ? const Color(0xFFFBBF24) : Colors.white70),
                                                          fontSize: 9.5,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.baseline,
                                              textBaseline: TextBaseline.alphabetic,
                                              children: [
                                                Text(
                                                  _getFormattedCheckTime(_todayAttendance?['check_out_time']),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                                if (_hasCheckedOut) ...[
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'WIB',
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.65),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _hasCheckedOut
                                                  ? (_getWorkDuration() ?? 'Shift Finished')
                                                  : (_hasCheckedIn
                                                      ? (_getWorkDuration() ?? 'Target: 17:00 WIB')
                                                      : 'Target: 17:00 WIB'),
                                              style: TextStyle(
                                                color: Colors.white.withValues(alpha: 0.65),
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Shift Timeline Progress Indicator (Fills space with useful, lively status)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _hasCheckedOut
                                        ? Icons.verified_rounded
                                        : (_hasCheckedIn ? Icons.timelapse_rounded : Icons.info_outline_rounded),
                                    size: 14,
                                    color: _hasCheckedOut
                                        ? const Color(0xFF34D399)
                                        : (_hasCheckedIn ? const Color(0xFFFBBF24) : Colors.white70),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _hasCheckedOut
                                          ? 'Daily work shift successfully completed (${_getWorkDuration() ?? "Full Day"})'
                                          : (_hasCheckedIn
                                              ? 'Active shift in progress • ${_getWorkDuration() ?? "Working"}'
                                              : 'Standard Working Hours: 08:00 - 17:00 WIB (8 hrs)'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    const SizedBox(height: 12),

                    // Central Circular Radar Attendance Action (or Completed Status)
                    _hasCheckedOut
                        ? _buildAttendanceCompletedCard()
                        : _CircularRadarAttendanceButton(
                            isCheckedIn: _hasCheckedIn,
                            onTap: () => _openAttendanceBottomSheet(!_hasCheckedIn),
                          ),

                    const SizedBox(height: 24),

                    // Quick Services / Applications & Requests Section Header
                    const Text(
                      'Applications & Services',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.2),
                    ),
                    const SizedBox(height: 14),

                    // Single Row: Attendance Log & Calendar Cards
                    Row(
                      children: [
                        Expanded(
                          child: _AnimatedActionCard(
                            title: 'Attendance Log',
                            subtitle: 'History & Records',
                            icon: Icons.receipt_long_rounded,
                            gradientColors: const [Color(0xFF059669), Color(0xFF10B981)],
                            accentColor: const Color(0xFF10B981),
                            bgPillColor: const Color(0xFFECFDF5),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AttendanceLogScreen()),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _AnimatedActionCard(
                            title: 'Calendar',
                            subtitle: 'Schedule & Shifts',
                            icon: Icons.event_available_rounded,
                            gradientColors: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                            accentColor: const Color(0xFF6366F1),
                            bgPillColor: const Color(0xFFEEF2FF),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CalendarScreen()),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Announcement Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.campaign_rounded, color: Color(0xFFDC2626), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Company Announcements',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Latest 3',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Dynamic Announcement Cards from Backend (Strictly 3 items)
                    if (_announcements.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Center(
                          child: Text(
                            'No announcements published yet',
                            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _announcements.take(3).map((ann) {
                          final title = ann['title']?.toString() ?? 'Announcement';
                          final category = ann['category']?.toString() ?? 'GENERAL';
                          final content = ann['content']?.toString() ?? '';
                          final createdAt = ann['created_at']?.toString() ?? '';
                          String formattedDate = '';
                          if (createdAt.length >= 10) {
                            formattedDate = createdAt.substring(0, 10);
                          }
                          final snippet = content.length > 90 ? '${content.substring(0, 90)}...' : content;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildAnnouncementCard(
                              title: title,
                              category: category,
                              date: formattedDate,
                              snippet: snippet,
                              content: content,
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _CircularRadarAttendanceButton extends StatefulWidget {
  final bool isCheckedIn;
  final VoidCallback onTap;

  const _CircularRadarAttendanceButton({
    required this.isCheckedIn,
    required this.onTap,
  });

  @override
  State<_CircularRadarAttendanceButton> createState() => _CircularRadarAttendanceButtonState();
}

class _CircularRadarAttendanceButtonState extends State<_CircularRadarAttendanceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not checked in: Button action is CHECK IN (Crimson Red theme)
    // If already checked in: Button action is CHECK OUT (Emerald Green theme)
    final bool isCheckInAction = !widget.isCheckedIn;

    final Color primaryColor = isCheckInAction
        ? const Color(0xFFDC2626) // Crimson Red
        : const Color(0xFF10B981); // Emerald Green

    final Color lightColor = isCheckInAction
        ? const Color(0xFFEF4444)
        : const Color(0xFF34D399);

    final Color darkColor = isCheckInAction
        ? const Color(0xFF991B1B)
        : const Color(0xFF047857);

    final String titleText = isCheckInAction ? 'CHECK IN' : 'CHECK OUT';

    const double buttonDiameter = 154.0;
    const double containerSize = 250.0;

    return Center(
      child: SizedBox(
        width: containerSize,
        height: containerSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated Radar Waves (Ripples + 360-deg Sweep Effect)
            AnimatedBuilder(
              animation: _radarController,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(containerSize, containerSize),
                  painter: _RadarWavePainter(
                    progress: _radarController.value,
                    color: primaryColor,
                    buttonRadius: buttonDiameter / 2,
                  ),
                );
              },
            ),

            // Ambient Radial Glow under the button
            Container(
              width: buttonDiameter + 12,
              height: buttonDiameter + 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.40),
                    blurRadius: 32,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
            ),

            // Interactive Circular Button with Tactile Tap Feedback
            GestureDetector(
              onTapDown: (_) => setState(() => _isPressed = true),
              onTapUp: (_) {
                setState(() => _isPressed = false);
                widget.onTap();
              },
              onTapCancel: () => setState(() => _isPressed = false),
              child: AnimatedScale(
                scale: _isPressed ? 0.93 : 1.0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeInOut,
                child: Container(
                  width: buttonDiameter,
                  height: buttonDiameter,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [lightColor, primaryColor, darkColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 3.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      titleText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarWavePainter extends CustomPainter {
  final double progress;
  final Color color;
  final double buttonRadius;

  _RadarWavePainter({
    required this.progress,
    required this.color,
    required this.buttonRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.width / 2) - 4;
    final maxExpansion = maxRadius - buttonRadius;

    // 1. Rotating Radar Sweep Gradient (360-degree sweep)
    final sweepAngle = progress * 2 * math.pi;
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.15),
        ],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius));
    canvas.drawCircle(center, maxRadius, sweepPaint);

    // 2. Concentric Expanding Radar Waves (3 Staggered Rings with Cubic Easing)
    const int ringCount = 3;
    for (int i = 0; i < ringCount; i++) {
      final ringProgress = (progress + (i / ringCount)) % 1.0;
      final curvedProgress = Curves.easeOutCubic.transform(ringProgress);
      final currentRadius = buttonRadius + (curvedProgress * maxExpansion);
      final opacity = ((1.0 - ringProgress) * 0.42).clamp(0.0, 1.0);

      // Translucent wave fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: opacity * 0.22)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, currentRadius, fillPaint);

      // Wave stroke outline
      final strokePaint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, currentRadius, strokePaint);
    }

    // 3. Faint Outer Radar Boundary Ring
    final boundaryPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, maxRadius, boundaryPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class _AnimatedActionCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final Color accentColor;
  final Color bgPillColor;
  final VoidCallback onTap;

  const _AnimatedActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.accentColor,
    required this.bgPillColor,
    required this.onTap,
  });

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeInOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lively Animated Glowing & Floating Icon Badge
              SizedBox(
                height: 72,
                width: 72,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final pulse = _pulseController.value;
                    final floatY = math.sin(pulse * 2 * math.pi) * 3.5;
                    final tiltAngle = math.cos(pulse * 2 * math.pi) * 0.045;
                    final shimmerX = -50.0 + (pulse * 120.0);
                    final sparkleOpacity = (0.3 + 0.7 * math.sin(pulse * 2 * math.pi).abs()).clamp(0.0, 1.0);

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Dynamic Expanding Concentric Wave Ripples
                        CustomPaint(
                          size: const Size(72, 72),
                          painter: _CardRipplePainter(
                            progress: pulse,
                            color: widget.accentColor,
                          ),
                        ),

                        // Levitating, Tilting Badge
                        Transform.translate(
                          offset: Offset(0, floatY),
                          child: Transform.rotate(
                            angle: tiltAngle,
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.accentColor.withValues(
                                      alpha: 0.35 + (0.15 * math.sin(pulse * 2 * math.pi).abs()),
                                    ),
                                    blurRadius: 14 + (6 * math.sin(pulse * 2 * math.pi).abs()),
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Stack(
                                  children: [
                                    // Rich Multi-stop Gradient Background
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: widget.gradientColors,
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          widget.icon,
                                          color: Colors.white,
                                          size: 27,
                                        ),
                                      ),
                                    ),

                                    // Moving Specular Light Beam / Gleam
                                    Transform.translate(
                                      offset: Offset(shimmerX, -10),
                                      child: Transform.rotate(
                                        angle: 0.45,
                                        child: Container(
                                          width: 18,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.white.withValues(alpha: 0.0),
                                                Colors.white.withValues(alpha: 0.45),
                                                Colors.white.withValues(alpha: 0.0),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Twinkling Sparkle Star Accent (Top-Right)
                        Positioned(
                          top: 2,
                          right: 4,
                          child: Opacity(
                            opacity: sparkleOpacity,
                            child: Transform.rotate(
                              angle: pulse * math.pi,
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 14,
                                color: widget.accentColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),

              // Subtitle
              Text(
                widget.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),

              // Animated Micro Action Pill
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final shift = math.sin(_pulseController.value * 2 * math.pi) * 2.5;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.bgPillColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: widget.accentColor,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Transform.translate(
                          offset: Offset(shift, 0),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: widget.accentColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CustomPainter for expanding card wave ripples
class _CardRipplePainter extends CustomPainter {
  final double progress;
  final Color color;

  _CardRipplePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double minR = 25.0;
    const double maxR = 36.0;

    for (int i = 0; i < 2; i++) {
      final waveProgress = (progress + (i * 0.5)) % 1.0;
      final radius = minR + (maxR - minR) * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.35;

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CardRipplePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// Lively Animated Completed Attendance Badge with expanding waves, levitation,
/// gleam shine sweep, and orbiting sparkle stars.
class _AnimatedAttendanceCompletedBadge extends StatefulWidget {
  const _AnimatedAttendanceCompletedBadge();

  @override
  State<_AnimatedAttendanceCompletedBadge> createState() =>
      _AnimatedAttendanceCompletedBadgeState();
}

class _AnimatedAttendanceCompletedBadgeState
    extends State<_AnimatedAttendanceCompletedBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 110,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = _controller.value;
          final floatY = math.sin(progress * 2 * math.pi) * 3.5;
          final shimmerX = -60.0 + (progress * 160.0);
          final starOpacity = (0.3 + 0.7 * math.sin(progress * 2 * math.pi).abs()).clamp(0.0, 1.0);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Concentric Emerald Expanding Wave Ripples
              CustomPaint(
                size: const Size(110, 110),
                painter: _CompletedRipplePainter(progress: progress),
              ),

              // Levitating Central Badge
              Transform.translate(
                offset: Offset(0, floatY),
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(
                          alpha: 0.35 + (0.15 * math.sin(progress * 2 * math.pi).abs()),
                        ),
                        blurRadius: 18 + (6 * math.sin(progress * 2 * math.pi).abs()),
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Inner Check Icon
                        const Icon(
                          Icons.task_alt_rounded,
                          color: Colors.white,
                          size: 40,
                        ),

                        // Moving Specular Gleam Sweep
                        Transform.translate(
                          offset: Offset(shimmerX, -10),
                          child: Transform.rotate(
                            angle: 0.45,
                            child: Container(
                              width: 22,
                              height: 100,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.0),
                                    Colors.white.withValues(alpha: 0.55),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Twinkling Sparkle Star Top-Right
              Positioned(
                top: 8,
                right: 14,
                child: Opacity(
                  opacity: starOpacity,
                  child: Transform.rotate(
                    angle: progress * 2 * math.pi,
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ),

              // Twinkling Sparkle Star Bottom-Left
              Positioned(
                bottom: 12,
                left: 14,
                child: Opacity(
                  opacity: (1.0 - starOpacity).clamp(0.2, 1.0),
                  child: Transform.rotate(
                    angle: -progress * 2 * math.pi,
                    child: const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompletedRipplePainter extends CustomPainter {
  final double progress;

  _CompletedRipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double minR = 38.0;
    const double maxR = 52.0;

    for (int i = 0; i < 2; i++) {
      final waveProgress = (progress + (i * 0.5)) % 1.0;
      final radius = minR + (maxR - minR) * waveProgress;
      final opacity = (1.0 - waveProgress) * 0.38;

      final paint = Paint()
        ..color = const Color(0xFF10B981).withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CompletedRipplePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
