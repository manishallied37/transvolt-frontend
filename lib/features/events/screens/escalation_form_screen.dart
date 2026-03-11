import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EscalationFormScreen extends StatelessWidget {
  final Map<String, dynamic> escalationDetailsArray;

  const EscalationFormScreen({
    Key? key,
    required this.escalationDetailsArray,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final driver = escalationDetailsArray['driver'] ?? {};
    final details = escalationDetailsArray['details'] ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text("Escalation Form")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Driver: ${driver['firstName']} ${driver['lastName']}"),
            Text("Driver ID: ${driver['driverId']}"),
            Text("Event Type: ${details['typeDescription']}"),
          ],
        ),
      ),
    );
  }
}