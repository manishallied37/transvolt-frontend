import 'package:flutter/material.dart';
import '../services/report_api.dart';
import 'package:fl_chart/fl_chart.dart';

class AuditReportScreen extends StatefulWidget {
  const AuditReportScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _AuditReportScreenState createState() => _AuditReportScreenState();
}

class _AuditReportScreenState extends State<AuditReportScreen> {
  final api = ReportApi();

  List data = [];
  List stats = [];
  bool loading = true;

  int page = 1;
  bool isLoadingMore = false;

  final ScrollController controller = ScrollController();

  String? selectedAction;
  DateTimeRange? dateRange;

  final actions = ['user:login', 'user:login_failed'];

  @override
  void initState() {
    super.initState();

    controller.addListener(() {
      if (controller.position.pixels == controller.position.maxScrollExtent) {
        loadMore();
      }
    });

    loadData();
  }

  Future loadMore() async {
    if (isLoadingMore) return;

    setState(() => isLoadingMore = true);

    page++;

    final res = await api.getAuditReport(page: page);

    setState(() {
      data.addAll(res.data['data']);
      isLoadingMore = false;
    });
  }

  Future loadData() async {
    setState(() {
      loading = true;
      page = 1;
    });

    try {
      final res = await api.getAuditReport(page: page);

      if (!mounted) return;
      setState(() {
        data = res.data['data'];
        loading = false;
      });

      final statsRes = await api.getAuditStats();

      if (!mounted) return;
      setState(() {
        stats = statsRes.data['data'];
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Failed to load report")));
    }
  }

  Future pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => dateRange = picked);
      loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Audit Report')),
      body: Column(
        children: [
          // 🔹 FILTERS
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    hint: Text("Action"),
                    initialValue: selectedAction,
                    items: actions.map((e) {
                      return DropdownMenuItem(value: e, child: Text(e));
                    }).toList(),
                    onChanged: (val) {
                      selectedAction = val;
                      loadData();
                    },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: pickDateRange,
                    child: Text("Date"),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () {
                    selectedAction = null;
                    dateRange = null;
                    loadData();
                  },
                ),
              ],
            ),
          ),

          if (!loading && data.isEmpty)
            Expanded(child: Center(child: Text("No data found"))),

          // 🔹 LOADER
          if (loading)
            Expanded(child: Center(child: CircularProgressIndicator())),

          if (!loading && stats.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: buildChart(stats),
            ),

          // 🔹 LIST
          if (!loading)
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: data.length + 1,
                itemBuilder: (context, i) {
                  if (i == data.length) {
                    return isLoadingMore
                        ? Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : SizedBox();
                  }

                  final item = data[i];

                  return ListTile(
                    title: Text(item['action']),
                    subtitle: Text("User: ${item['actor_id']}"),
                    trailing: Text(item['created_at']),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

Widget buildChart(List stats) {
  return SizedBox(
    height: 200,
    child: BarChart(
      BarChartData(
        barGroups: stats.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;

          return BarChartGroupData(
            x: i,
            barRods: [BarChartRodData(toY: double.parse(item['count']))],
          );
        }).toList(),
      ),
    ),
  );
}
