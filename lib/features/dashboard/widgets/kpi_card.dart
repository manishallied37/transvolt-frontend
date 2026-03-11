import 'package:flutter/material.dart';
import '../../../shared/widgets/app_card.dart';

class KpiCard extends StatelessWidget {

  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return AppCard(
      onTap: onTap,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          /// Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),

          const Spacer(),

          /// Value
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          /// Subtitle
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}