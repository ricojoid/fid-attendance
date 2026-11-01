import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'motion.dart';

/// "This request will be sent to …" — shown on leave & correction forms so the
/// employee knows exactly who receives their request before submitting.
class ApproverBanner extends StatelessWidget {
  const ApproverBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ApiService.getMyApprover(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.only(bottom: 16), child: Shimmer(height: 64));
        }
        final a = snap.data;
        final name = a?['name']?.toString();
        final role = (a?['role'] ?? '').toString().replaceAll('_', ' ').toLowerCase();
        return FadeSlideIn(
          offset: const Offset(0, 10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 18),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: name == null ? const Color(0xFFFFFBEB) : AppColors.info.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: name == null ? const Color(0xFFFDE68A) : AppColors.info.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: name == null ? AppColors.warning : AppColors.info,
                  child: Text(
                    name == null || name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WILL BE SENT FOR APPROVAL TO',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: AppColors.textFaint)),
                      const SizedBox(height: 2),
                      Text(
                        name ?? 'No approver found — please contact HR',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      if (name != null && role.isNotEmpty)
                        Text(
                          '${role[0].toUpperCase()}${role.substring(1)}${(a?['department'] ?? '').toString().isNotEmpty ? ' · ${a!['department']}' : ''}',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ),
                Icon(name == null ? Icons.warning_amber_rounded : Icons.verified_user_rounded,
                    color: name == null ? AppColors.warning : AppColors.info),
              ],
            ),
          ),
        );
      },
    );
  }
}
