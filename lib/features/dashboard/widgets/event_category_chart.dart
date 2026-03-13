import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../shared/widgets/app_card.dart';

class EventCategoryChart extends StatelessWidget {

  final int critical;
  final int high;
  final int medium;
  final int low;

  const EventCategoryChart({
    super.key,
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
  });

  @override
  Widget build(BuildContext context) {

    final total = critical + high + medium + low;

    return AppCard(

      padding: const EdgeInsets.all(16),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// TITLE
          const Text(
            "Event Categories",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          /// CHART
          SizedBox(
            height: 180,
            child: PieChart(

              PieChartData(

                sectionsSpace: 3,
                centerSpaceRadius: 38,

                sections: [

                  PieChartSectionData(
                    value: critical.toDouble(),
                    color: Colors.red,
                    radius: 55,
                    title:
                    "${((critical / total) * 100).toStringAsFixed(0)}%",
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  PieChartSectionData(
                    value: high.toDouble(),
                    color: Colors.orange,
                    radius: 55,
                    title:
                    "${((high / total) * 100).toStringAsFixed(0)}%",
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  PieChartSectionData(
                    value: medium.toDouble(),
                    color: Colors.green.shade700,
                    radius: 55,
                    title:
                    "${((medium / total) * 100).toStringAsFixed(0)}%",
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  PieChartSectionData(
                    value: low.toDouble(),
                    color: Colors.blue,
                    radius: 55,
                    title:
                    "${((low / total) * 100).toStringAsFixed(0)}%",
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// LEGEND
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 16,
            runSpacing: 8,
            children: const [

              LegendItem("Alert", Colors.red),
              LegendItem("Warn", Colors.orange),
              LegendItem("Driver Star", Colors.green),
              LegendItem("Neutral", Colors.blue),

            ],
          ),
        ],
      ),
    );
  }
}

class LegendItem extends StatelessWidget {

  final String label;
  final Color color;

  const LegendItem(this.label, this.color, {super.key});

  @override
  Widget build(BuildContext context) {

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [

        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 6),

        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}