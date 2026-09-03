import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceSuccessScreen extends StatefulWidget {
  final bool isCheckIn;
  final DateTime timestamp;
  final String address;
  final String? notes;
  final dynamic imageFile; // File or XFile

  const AttendanceSuccessScreen({
    super.key,
    required this.isCheckIn,
    required this.timestamp,
    required this.address,
    this.notes,
    this.imageFile,
  });

  @override
  State<AttendanceSuccessScreen> createState() => _AttendanceSuccessScreenState();
}

class _AttendanceSuccessScreenState extends State<AttendanceSuccessScreen>
    with TickerProviderStateMixin {
  AnimationController? _introController;
  AnimationController? _waveController;
  AnimationController? _floatController;

  late Animation<double> _iconScale;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void reassemble() {
    super.reassemble();
    _initControllers();
  }

  void _initControllers() {
    if (_introController == null) {
      _introController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      );

      _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _introController!,
          curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
        ),
      );

      _contentSlide = Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _introController!,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
        ),
      );

      _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _introController!,
          curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
        ),
      );

      _introController!.forward();
    }

    if (_waveController == null) {
      _waveController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2500),
      )..repeat();
    }

    if (_floatController == null) {
      _floatController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3600),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _introController?.dispose();
    _waveController?.dispose();
    _floatController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _initControllers();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(widget.timestamp);
    final timeStr = DateFormat('HH:mm:ss').format(widget.timestamp);
    final typeText = widget.isCheckIn ? 'Check-In' : 'Check-Out';

    // Check-In = Emerald Green, Check-Out = Crimson Red
    final primaryColor = widget.isCheckIn ? const Color(0xFF10B981) : const Color(0xFFDC2626);
    final primaryDark = widget.isCheckIn ? const Color(0xFF047857) : const Color(0xFF991B1B);
    final primaryLight = widget.isCheckIn ? const Color(0xFF34D399) : const Color(0xFFEF4444);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Ambient Background Glow Orbs & Festive Ornaments
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _floatController!,
              builder: (context, _) {
                final floatOffset = math.sin(_floatController!.value * math.pi) * 12.0;
                return Stack(
                  children: [
                    // Top-Right Glowing Gradient Orb
                    Positioned(
                      top: -60 + floatOffset,
                      right: -50,
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              primaryColor.withValues(alpha: 0.18),
                              primaryColor.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top-Left Subtle Ambient Orb
                    Positioned(
                      top: 100 - floatOffset,
                      left: -70,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF38BDF8).withValues(alpha: 0.10),
                              const Color(0xFF38BDF8).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Floating Celebration Confetti Particles
                    ..._buildFloatingOrnaments(primaryColor, floatOffset),
                  ],
                );
              },
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    // Animated Logo Badge with Continuous Wave Radiance
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Looping Concentric Wave Ripples Painter
                          AnimatedBuilder(
                            animation: _waveController!,
                            builder: (context, _) {
                              return CustomPaint(
                                size: const Size(200, 200),
                                painter: _SuccessWavePainter(
                                  progress: _waveController!.value,
                                  color: primaryColor,
                                ),
                              );
                            },
                          ),

                          // Decorative Floating Sparkles around the badge
                          AnimatedBuilder(
                            animation: _waveController!,
                            builder: (context, _) {
                              return CustomPaint(
                                size: const Size(200, 200),
                                painter: _SparkleOrnamentsPainter(
                                  progress: _waveController!.value,
                                  color: primaryColor,
                                ),
                              );
                            },
                          ),

                          // Central Elastic Checkmark Badge
                          ScaleTransition(
                            scale: _iconScale,
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [primaryLight, primaryColor, primaryDark],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  width: 3.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.45),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 46,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Slide & Fade Animated Content
                    SlideTransition(
                      position: _contentSlide,
                      child: FadeTransition(
                        opacity: _contentFade,
                        child: Column(
                          children: [
                            // Status Pill Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.28),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.6),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ATTENDANCE RECORDED',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      color: primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Main Title
                            Text(
                              '$typeText Successful!',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Subtitle
                            const Text(
                              'Your attendance has been verified and safely recorded in the system.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 26),

                            // Detail Information Card
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Time Showcase Banner
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                      border: const Border(
                                        bottom: BorderSide(color: Color(0xFFF1F5F9)),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'RECORDED TIME',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.0,
                                                color: const Color(0xFF94A3B8),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              timeStr,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A),
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: primaryColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            'WIB',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Information Rows
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        // Date Row
                                        _buildDetailRow(
                                          icon: Icons.calendar_today_rounded,
                                          label: 'Attendance Date',
                                          value: dateStr,
                                          iconColor: const Color(0xFF3B82F6),
                                        ),
                                        const Divider(height: 24, color: Color(0xFFF1F5F9)),

                                        // Status / Type Row
                                        _buildDetailRow(
                                          icon: widget.isCheckIn
                                              ? Icons.login_rounded
                                              : Icons.logout_rounded,
                                          label: 'Attendance Type',
                                          value: '$typeText (Verified)',
                                          iconColor: primaryColor,
                                        ),
                                        const Divider(height: 24, color: Color(0xFFF1F5F9)),

                                        // Location Row
                                        _buildDetailRow(
                                          icon: Icons.location_on_rounded,
                                          label: 'Recorded Location',
                                          value: widget.address.isNotEmpty
                                              ? widget.address
                                              : 'Current GPS Coordinates',
                                          iconColor: const Color(0xFFDC2626),
                                        ),

                                        // Optional Notes Row
                                        if (widget.notes != null && widget.notes!.isNotEmpty) ...[
                                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                          _buildDetailRow(
                                            icon: Icons.notes_rounded,
                                            label: 'Attendance Note',
                                            value: widget.notes!,
                                            iconColor: const Color(0xFFD97706),
                                          ),
                                        ],

                                        // Optional Selfie Photo Row
                                        if (widget.imageFile != null) ...[
                                          const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Row(
                                                children: [
                                                  Icon(
                                                    Icons.camera_alt_rounded,
                                                    size: 16,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Attached Photo Verification',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(14),
                                                child: _buildImagePreview(widget.imageFile),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Return to Home Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context, true);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Done & Return to Home',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Floating celebration ornaments generator
  List<Widget> _buildFloatingOrnaments(Color primaryColor, double floatOffset) {
    return [
      // Ornament 1: Diamond top-left
      Positioned(
        top: 60 + floatOffset * 0.8,
        left: 28,
        child: Transform.rotate(
          angle: 0.4,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
      // Ornament 2: Circle top-right
      Positioned(
        top: 130 - floatOffset * 0.7,
        right: 36,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
            shape: BoxShape.circle,
          ),
        ),
      ),
      // Ornament 3: Capsule mid-left
      Positioned(
        top: 220 + floatOffset * 0.5,
        left: 20,
        child: Container(
          width: 8,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      // Ornament 4: Diamond mid-right
      Positioned(
        top: 260 - floatOffset * 0.6,
        right: 24,
        child: Transform.rotate(
          angle: 0.7,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview(dynamic img) {
    if (kIsWeb) {
      if (img is String) {
        return Image.network(img, height: 160, width: double.infinity, fit: BoxFit.cover);
      }
      return Container(
        height: 150,
        width: double.infinity,
        color: const Color(0xFFF1F5F9),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 36),
            SizedBox(height: 6),
            Text(
              'Selfie Photo Attached',
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    } else {
      if (img is File) {
        return Image.file(img, height: 160, width: double.infinity, fit: BoxFit.cover);
      }
      return Container(
        height: 150,
        width: double.infinity,
        color: const Color(0xFFF1F5F9),
        child: const Icon(Icons.photo, size: 48, color: Color(0xFF94A3B8)),
      );
    }
  }
}

/// CustomPainter that renders expanding multi-layer wave ripples behind the success badge
class _SuccessWavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _SuccessWavePainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const double minRadius = 45.0;
    const double maxRadius = 96.0;

    const int waveCount = 3;

    for (int i = 0; i < waveCount; i++) {
      final waveProgress = (progress + (i / waveCount)) % 1.0;
      final easedProgress = Curves.easeOutCubic.transform(waveProgress);
      final radius = minRadius + (maxRadius - minRadius) * easedProgress;

      // Opacity fades smoothly as the wave expands outwards
      final alpha = ((1.0 - waveProgress) * 0.42).clamp(0.0, 1.0);

      // Ripple wave fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: alpha * 0.28)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);

      // Ripple wave outer ring
      final strokePaint = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1.0 - waveProgress);
      canvas.drawCircle(center, radius, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SuccessWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

/// CustomPainter that renders sparkling stars / ornaments around the success badge
class _SparkleOrnamentsPainter extends CustomPainter {
  final double progress;
  final Color color;

  _SparkleOrnamentsPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 4 decorative sparkle stars placed at 45, 135, 225, 315 degrees
    final angles = [
      math.pi / 4,
      3 * math.pi / 4,
      5 * math.pi / 4,
      7 * math.pi / 4,
    ];

    const double sparkleOrbitRadius = 66.0;

    for (int i = 0; i < angles.length; i++) {
      final angle = angles[i];
      final sparkleX = center.dx + sparkleOrbitRadius * math.cos(angle);
      final sparkleY = center.dy + sparkleOrbitRadius * math.sin(angle);

      // Oscillating scale and opacity based on progress and sparkle index
      final phase = (progress * 2 * math.pi) + (i * math.pi / 2);
      final scale = 0.5 + 0.5 * math.sin(phase).abs();
      final alpha = (0.3 + 0.7 * math.sin(phase).abs()).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: alpha * 0.75)
        ..style = PaintingStyle.fill;

      // Draw 4-point sparkle star
      _drawSparkleStar(canvas, Offset(sparkleX, sparkleY), 6.0 * scale, paint);
    }
  }

  void _drawSparkleStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    path.moveTo(center.dx, center.dy - size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkleOrnamentsPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
