import 'dart:io';
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

class _AttendanceSuccessScreenState extends State<AttendanceSuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconScale;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _rippleScale = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _rippleOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _contentFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(widget.timestamp);
    final timeStr = DateFormat('HH:mm:ss').format(widget.timestamp);
    final typeText = widget.isCheckIn ? 'Check-In' : 'Check-Out';
    final primaryColor = widget.isCheckIn ? const Color(0xFF10B981) : const Color(0xFFDC2626);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Success Badge Icon with Ripple Effect
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ripple pulse ring
                        Transform.scale(
                          scale: _rippleScale.value,
                          child: Opacity(
                            opacity: _rippleOpacity.value,
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        // Inner elastic checkmark icon
                        ScaleTransition(
                          scale: _iconScale,
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: primaryColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Slide & Fade Content
                SlideTransition(
                  position: _contentSlide,
                  child: FadeTransition(
                    opacity: _contentFade,
                    child: Column(
                      children: [
                        Text(
                          '$typeText Successful!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your presence has been successfully recorded in the system.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Card Detail
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Date & Time Row
                              _buildDetailRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Attendance Date',
                                value: dateStr,
                                iconColor: const Color(0xFFDC2626),
                              ),
                              const Divider(height: 24, color: Color(0xFFF1F5F9)),

                              _buildDetailRow(
                                icon: Icons.access_time_filled_rounded,
                                label: 'Time ($typeText)',
                                value: '$timeStr WIB',
                                iconColor: primaryColor,
                              ),

                              if (widget.notes != null && widget.notes!.isNotEmpty) ...[
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                _buildDetailRow(
                                  icon: Icons.notes_rounded,
                                  label: 'Attendance Notes',
                                  value: widget.notes!,
                                  iconColor: Colors.amber[700]!,
                                ),
                              ],

                              if (widget.imageFile != null) ...[
                                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.camera_alt_rounded, size: 18, color: Color(0xFF64748B)),
                                        SizedBox(width: 8),
                                        Text(
                                          'Selfie Photo Attached',
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
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildImagePreview(widget.imageFile),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Button back to Home
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFDC2626),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 2,
                            ),
                            child: const Text(
                              'Done & Return to Home',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
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
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
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
        height: 160,
        width: double.infinity,
        color: const Color(0xFFE2E8F0),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 40),
            SizedBox(height: 6),
            Text('Selfie Photo Attached', style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold)),
          ],
        ),
      );
    } else {
      if (img is File) {
        return Image.file(img, height: 160, width: double.infinity, fit: BoxFit.cover);
      }
      return Container(
        height: 160,
        width: double.infinity,
        color: const Color(0xFFE2E8F0),
        child: const Icon(Icons.photo, size: 48, color: Color(0xFF94A3B8)),
      );
    }
  }
}
