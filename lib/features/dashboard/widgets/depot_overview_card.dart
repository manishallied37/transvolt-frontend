import 'package:flutter/material.dart';
import '../../../shared/widgets/app_card.dart';

class DepotOverviewCard extends StatelessWidget {

  final String depotName;
  final int events;
  final VoidCallback? onTap;

  const DepotOverviewCard({
    super.key,
    required this.depotName,
    required this.events,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return AppCard(

      onTap: onTap,

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          /// Depot Name
          Text(
            depotName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          /// Event Count
          Text(
            "$events Events",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

        ],
      ),
    );
  }
}