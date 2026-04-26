import 'package:flutter/material.dart';

class OfflineBanner extends StatelessWidget {
  final bool isOnline;

  const OfflineBanner({
    super.key,
    required this.isOnline,
  });

  @override
  Widget build(BuildContext context) {
    final title = isOnline ? 'Cached data' : 'No internet connection';

    final subtitle = isOnline
        ? 'Showing cached data while the app refreshes.'
        : 'You are viewing saved products. Pagination is paused until you are back online.';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cached : Icons.wifi_off,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}