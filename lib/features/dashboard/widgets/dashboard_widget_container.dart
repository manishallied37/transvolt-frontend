import 'package:flutter/material.dart';
import '../../../shared/widgets/app_card.dart';

class DashboardWidgetContainer extends StatelessWidget {

  final Widget child;
  final String title;
  final VoidCallback? onTap;

  const DashboardWidgetContainer({
    super.key,
    required this.child,
    required this.title,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),

      child: AppCard(

        onTap: onTap,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            /// Widget Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            /// Actual widget content
            child,
          ],
        ),
      ),
    );
  }
}