import 'dart:convert';
import 'dart:io';
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

class _HomeScreenState extends State<HomeScreen> {
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

  @override
  void initState() {
    super.initState();
    ApiService.profilePhotoNotifier.addListener(_onPhotoChanged);
    _fetchTodayData();
    _determinePosition();
  }

  @override
  void dispose() {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final typeText = isCheckIn ? 'Check-In' : 'Check-Out';
            final primaryColor = isCheckIn ? const Color(0xFF10B981) : const Color(0xFFDC2626);

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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Attendance notes are required. Please enter your note.'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setModalState(() => isSubmittingModal = true);
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
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString().replaceAll('Exception: ', '')),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
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
                            color: primaryColor.withOpacity(0.12),
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
                    const Text(
                      'Attendance Notes (Required) *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Working from Office / WFH / Client Meeting',
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
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
                                  const SizedBox(width: 10),
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
                    const SizedBox(height: 24),

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
            );
          },
        );
      },
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
                                Row(
                                  children: [
                                    Text(
                                      _getGreeting(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFECFDF5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.circle, color: Color(0xFF10B981), size: 6),
                                          SizedBox(width: 4),
                                          Text(
                                            'Active',
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                          // Location Chip
                          InkWell(
                            onTap: () => _showMapDialog(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFCA5A5).withOpacity(0.5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.location_on_rounded, color: Color(0xFFDC2626), size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'GPS',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                                  ),
                                ],
                              ),
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
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.login_rounded, color: Color(0xFF6EE7B7), size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Check In',
                                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _getFormattedCheckTime(_todayAttendance?['check_in_time']),
                                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.logout_rounded, color: Color(0xFFFCA5A5), size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Check Out',
                                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _getFormattedCheckTime(_todayAttendance?['check_out_time']),
                                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Check In / Check Out Actions
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: _hasCheckedIn
                                  ? null
                                  : const LinearGradient(
                                      colors: [Color(0xFF10B981), Color(0xFF059669)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              boxShadow: _hasCheckedIn
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: (_hasCheckedIn) ? null : () => _openAttendanceBottomSheet(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasCheckedIn ? Icons.check_circle_rounded : Icons.login_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _hasCheckedIn ? 'Checked In' : 'Check In',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Container(
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: (!_hasCheckedIn || _hasCheckedOut)
                                  ? null
                                  : const LinearGradient(
                                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                              boxShadow: (!_hasCheckedIn || _hasCheckedOut)
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: const Color(0xFFDC2626).withOpacity(0.35),
                                        blurRadius: 14,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                            ),
                            child: ElevatedButton(
                              onPressed: (!_hasCheckedIn || _hasCheckedOut) ? null : () => _openAttendanceBottomSheet(false),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                disabledBackgroundColor: const Color(0xFFDC2626).withOpacity(0.2),
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _hasCheckedOut ? Icons.check_circle_rounded : Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _hasCheckedOut ? 'Checked Out' : 'Check Out',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

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
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF64748B).withOpacity(0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AttendanceLogScreen()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFECFDF5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.history_rounded, color: Color(0xFF10B981), size: 24),
                                      ),
                                      const SizedBox(height: 12),
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Attendance Log',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF64748B).withOpacity(0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEEF2FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 24),
                                      ),
                                      const SizedBox(height: 12),
                                      const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Calendar',
                                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF94A3B8)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
