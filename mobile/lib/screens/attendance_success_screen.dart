import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AttendanceSuccessScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(timestamp);
    final timeStr = DateFormat('HH:mm:ss').format(timestamp);
    final typeText = isCheckIn ? 'Check-In' : 'Check-Out';
    final primaryColor = isCheckIn ? const Color(0xFF10B981) : const Color(0xFFF43F5E);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Success Badge Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.4),
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
                const SizedBox(height: 24),

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
                        color: Colors.black.withOpacity(0.03),
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
                        iconColor: Colors.blueAccent,
                      ),
                      const Divider(height: 24, color: Color(0xFFF1F5F9)),

                      _buildDetailRow(
                        icon: Icons.access_time_filled_rounded,
                        label: 'Time ($typeText)',
                        value: '$timeStr WIB',
                        iconColor: primaryColor,
                      ),

                      if (notes != null && notes!.isNotEmpty) ...[
                        const Divider(height: 24, color: Color(0xFFF1F5F9)),
                        _buildDetailRow(
                          icon: Icons.notes_rounded,
                          label: 'Attendance Notes',
                          value: notes!,
                          iconColor: Colors.amber[700]!,
                        ),
                      ],

                      if (imageFile != null) ...[
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
                              child: _buildImagePreview(imageFile),
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
                      backgroundColor: const Color(0xFF2563EB),
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
            color: iconColor.withOpacity(0.1),
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
