import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/escalation_api.dart';

class EscalationReviewScreen extends StatefulWidget {
  final String escalationId;
  const EscalationReviewScreen({super.key, required this.escalationId});

  @override
  State<EscalationReviewScreen> createState() => _EscalationReviewScreenState();
}

class _EscalationReviewScreenState extends State<EscalationReviewScreen> {
  final EscalationApi api = EscalationApi();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Map? escalation;
  List evidence = [];
  List comments = [];
  bool loading = true;
  bool submittingComment = false;
  bool submittingStatus = false;

  String? selectedStatus;
  final TextEditingController _reasonController = TextEditingController();

  final Map<String, String> _downloadingFiles = {};

  final List<Map<String, String>> _statusOptions = [
    {
      'value': 'UNDER_REVIEW',
      'label': 'Under review',
      'reason': 'Mark as currently being reviewed',
    },
    {
      'value': 'ESCALATED_TO_AUTHORITY',
      'label': 'Escalate to authority',
      'reason': 'Forward to relevant authority for action',
    },
    {
      'value': 'CLOSED',
      'label': 'Close incident',
      'reason': 'Incident reviewed and resolved',
    },
    {
      'value': 'REJECTED',
      'label': 'Reject escalation',
      'reason': 'Escalation found invalid or duplicate',
    },
  ];

  @override
  void initState() {
    super.initState();
    loadEscalation();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _reasonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadEscalation() async {
    try {
      final response = await api.getEscalationById(widget.escalationId);
      setState(() {
        escalation = response["escalation"]; // could be null if id not found
        evidence = response["evidence"] ?? [];
        comments = response["comments"] ?? [];
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
        escalation = null; // ← explicit null on error
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to load: $e")));
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => submittingComment = true);
    try {
      await api.addEscalationComment(
        widget.escalationId,
        _commentController.text.trim(),
      );
      _commentController.clear();
      await loadEscalation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
    setState(() => submittingComment = false);
  }

  Future<void> _openFile(Map file) async {
    // Prepend base URL, strip /api since uploads are served from root
    final baseUrl = api.baseUrl.replaceAll('/api', ''); // http://localhost:5000
    final relativePath = file["file_url"] as String? ?? "";
    final fullUrl =
        "$baseUrl$relativePath"; // http://localhost:5000/uploads/evidence/xxx.jpg

    final fileName =
        file["file_name"] as String? ?? relativePath.split("/").last;

    setState(() => _downloadingFiles[fileName] = "downloading");

    try {
      final dir = await getTemporaryDirectory();
      final savePath = "${dir.path}/$fileName";
      final savedFile = File(savePath);

      if (!savedFile.existsSync()) {
        await Dio().download(fullUrl, savePath);
      }

      setState(() => _downloadingFiles.remove(fileName));
      await OpenFilex.open(savePath);
    } catch (e) {
      setState(() => _downloadingFiles.remove(fileName));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to open file: $e")));
      }
    }
  }

  void _showStatusSheet() {
    selectedStatus = null;
    _reasonController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: ListView(
            controller: _scrollController,
            shrinkWrap: true,
            children: [
              const Text(
                "Update status",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              const Text(
                "Select a new status and provide a reason",
                style: TextStyle(fontSize: 13, color: Colors.black45),
              ),
              const SizedBox(height: 16),

              // Status options
              ..._statusOptions.map((opt) {
                final isSelected = selectedStatus == opt['value'];
                return GestureDetector(
                  onTap: () =>
                      setSheetState(() => selectedStatus = opt['value']),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFEEEDFE)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF534AB7)
                            : Colors.transparent,
                        width: isSelected ? 1 : 0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                opt['label']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFF3C3489)
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                opt['reason']!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF534AB7),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Reason (required)",
                  labelStyle: const TextStyle(fontSize: 13),
                  hintText: "Explain the reason for this status change...",
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Colors.black38,
                  ),
                  alignLabelWithHint: true,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Colors.black12,
                      width: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: submittingStatus
                      ? null
                      : () async {
                          if (selectedStatus == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please select a status"),
                              ),
                            );
                            return;
                          }
                          if (_reasonController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please provide a reason"),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(ctx);
                          setState(() => submittingStatus = true);
                          try {
                            await api.updateEscalationStatus(
                              widget.escalationId,
                              selectedStatus!,
                            );
                            await api.addEscalationComment(
                              widget.escalationId,
                              _reasonController.text.trim(),
                              commentType: "STATUS_CHANGE",
                              statusChangedTo: selectedStatus,
                            );
                            await loadEscalation();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Status updated successfully"),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e")),
                              );
                            }
                          }
                          setState(() => submittingStatus = false);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF534AB7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: submittingStatus
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          "Confirm status change",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Escalation review",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        actions: [
          if (!loading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: submittingStatus ? null : _showStatusSheet,
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text(
                  "Update status",
                  style: TextStyle(fontSize: 13),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF534AB7),
                  backgroundColor: const Color(0xFFEEEDFE),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.black12),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : escalation == null
          ? _buildErrorState()
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildIncidentCard(),
                      const SizedBox(height: 14),
                      _buildEvidenceSection(),
                      const SizedBox(height: 14),
                      _buildCommentsSection(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                _buildCommentInput(),
              ],
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.black26,
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            "Failed to load escalation",
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() => loading = true);
              loadEscalation();
            },
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }

  // — Incident Detail Card —
  Widget _buildIncidentCard() {
    final e = escalation!;
    final sevLevel = (e['severity_level'] as num?)?.toInt() ?? 1;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e['escalation_type'] ?? '-',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${e['event_sub_type'] ?? '-'} · Event #${e['event_id'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusPill(e['status']),
                  const SizedBox(height: 4),
                  _severityPill(sevLevel, e['severity_description']),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.5, color: Colors.black12),
          const SizedBox(height: 14),

          Row(
            children: [
              _infoItem("Driver", e['driver_name'] ?? '-'),
              _infoItem("Vehicle", e['vehicle_id'] ?? '-'),
              _infoItem("City", e['city'] ?? '-'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoItem("Event type", e['event_type'] ?? '-'),
              _infoItem("Weather", e['weather_prediction'] ?? '-'),
              _infoItem("Impact", e['point_of_impact'] ?? '-'),
            ],
          ),
          const SizedBox(height: 12),

          if (e['comment'] != null && e['comment'].toString().isNotEmpty) ...[
            const Divider(height: 1, thickness: 0.5, color: Colors.black12),
            const SizedBox(height: 12),
            _sectionLabel("Initial comment"),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                e['comment'],
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.5, color: Colors.black12),
          const SizedBox(height: 12),

          // Metrics row
          Row(
            children: [
              _metricTile(
                "Max speed",
                "${double.tryParse(e['max_vehicle_speed']?.toString() ?? '0')?.toStringAsFixed(0)} km/h",
                Icons.speed_rounded,
              ),
              const SizedBox(width: 10),
              _metricTile(
                "G-force",
                double.tryParse(
                      e['max_g_force']?.toString() ?? '0',
                    )?.toStringAsFixed(2) ??
                    '-',
                Icons.vibration_rounded,
              ),
              const SizedBox(width: 10),
              _metricTile(
                "Confidence",
                "${((double.tryParse(e['confidence']?.toString() ?? '0') ?? 0) * 100).toStringAsFixed(0)}%",
                Icons.verified_rounded,
              ),
            ],
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              _infoItem("Recorded", _formatDate(e['event_timestamp']), flex: 2),
              _infoItem("Submitted", _formatDate(e['created_at'])),
            ],
          ),
        ],
      ),
    );
  }

  // — Evidence Section —
  Widget _buildEvidenceSection() {
    if (evidence.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel("Evidence files"),
              Text(
                "${evidence.length} file(s)",
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...evidence.map((file) {
            final type = (file["file_type"] as String? ?? "").toLowerCase();
            // final url = file["file_url"] as String? ?? "";
            final fileName =
                file["file_name"] as String? ??
                (file["file_url"] as String? ?? "").split("/").last;
            final isDownloading = _downloadingFiles.containsKey(fileName);
            final isImage = type.startsWith("image/");
            final isVideo = type.startsWith("video/");
            final isPdf = type.contains("pdf");

            IconData icon = Icons.insert_drive_file_outlined;
            Color iconColor = Colors.black38;
            Color iconBg = const Color(0xFFF1EFE8);
            if (isImage) {
              icon = Icons.image_outlined;
              iconColor = const Color(0xFF185FA5);
              iconBg = const Color(0xFFE6F1FB);
            } else if (isVideo) {
              icon = Icons.videocam_outlined;
              iconColor = const Color(0xFF854F0B);
              iconBg = const Color(0xFFFAEEDA);
            } else if (isPdf) {
              icon = Icons.picture_as_pdf_outlined;
              iconColor = const Color(0xFFA32D2D);
              iconBg = const Color(0xFFFCEBEB);
            }

            return GestureDetector(
              onTap: isDownloading ? null : () => _openFile(file),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            type.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isDownloading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black38,
                        ),
                      )
                    else
                      const Icon(
                        Icons.open_in_new_rounded,
                        size: 16,
                        color: Colors.black38,
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // — Comments Section —
  Widget _buildCommentsSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel("Discussion"),
              Text(
                "${comments.length} comment(s)",
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (comments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: const Column(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: Colors.black26,
                    size: 28,
                  ),
                  SizedBox(height: 8),
                  Text(
                    "No comments yet",
                    style: TextStyle(fontSize: 13, color: Colors.black38),
                  ),
                ],
              ),
            )
          else
            ...comments.map((c) => _buildCommentBubble(c)),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(Map c) {
    final isStatusChange = c['comment_type'] == 'STATUS_CHANGE';
    final role = c['user_role'] as String? ?? '';

    if (isStatusChange) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            // Status change pill row
            Row(
              children: [
                const Expanded(
                  child: Divider(thickness: 0.5, color: Colors.black12),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDFE),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.swap_horiz_rounded,
                        size: 13,
                        color: Color(0xFF534AB7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Status → ${_statusLabel(c['status_changed_to'])}",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF3C3489),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Expanded(
                  child: Divider(thickness: 0.5, color: Colors.black12),
                ),
              ],
            ),

            // Reason bubble below
            if (c['comment'] != null && c['comment'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _roleColor(role)['bg'],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _initials(c['user_name']),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _roleColor(role)['text'],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              c['user_name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _roleBadge(role),
                            const Spacer(),
                            Text(
                              _formatDate(c['created_at']),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEEEDFE),
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(10),
                              bottomLeft: Radius.circular(10),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Text(
                            c['comment'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF3C3489),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    // Normal comment bubble
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _roleColor(role)['bg'],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _initials(c['user_name']),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _roleColor(role)['text'],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      c['user_name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _roleBadge(role),
                    const Spacer(),
                    Text(
                      _formatDate(c['created_at']),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(10),
                      bottomLeft: Radius.circular(10),
                      bottomRight: Radius.circular(10),
                    ),
                  ),
                  child: Text(
                    c['comment'] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // — Comment Input —
  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: "Add a comment...",
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.black12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(
                    color: Colors.black12,
                    width: 0.5,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: submittingComment ? null : _submitComment,
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF534AB7),
                shape: BoxShape.circle,
              ),
              child: submittingComment
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // — Helpers —
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
    ),
    child: child,
  );

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.black45,
      letterSpacing: 0.3,
    ),
  );

  Widget _infoItem(String label, String value, {int flex = 1}) => Expanded(
    flex: flex,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black38),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ],
    ),
  );

  Widget _metricTile(String label, String value, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.black38),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
    ),
  );

  Widget _statusPill(String? status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _statusBg(status),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      _statusLabel(status),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: _statusColor(status),
      ),
    ),
  );

  Widget _severityPill(int level, String? desc) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: _sevColor(level),
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        desc ?? '-',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _sevColor(level),
        ),
      ),
    ],
  );

  Widget _roleBadge(String role) {
    final colors = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors['bg'],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: colors['text'],
        ),
      ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  Map<String, Color> _roleColor(String role) {
    switch (role.toUpperCase()) {
      case 'CC':
        return {'bg': const Color(0xFFE6F1FB), 'text': const Color(0xFF185FA5)};
      case 'AUTHORITY':
        return {'bg': const Color(0xFFFAEEDA), 'text': const Color(0xFF854F0B)};
      case 'ADMIN':
        return {'bg': const Color(0xFFEEEDFE), 'text': const Color(0xFF534AB7)};
      default:
        return {'bg': const Color(0xFFF1EFE8), 'text': const Color(0xFF5F5E5A)};
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'ESCALATED_TO_CC':
        return 'Escalated to CC';
      case 'UNDER_REVIEW':
        return 'Under review';
      case 'ESCALATED_TO_AUTHORITY':
        return 'Escalated to authority';
      case 'CLOSED':
        return 'Closed';
      case 'REJECTED':
        return 'Rejected';
      default:
        return s ?? '-';
    }
  }

  Color _statusColor(String? s) {
    switch (s) {
      case 'ESCALATED_TO_CC':
        return const Color(0xFF534AB7);
      case 'UNDER_REVIEW':
        return const Color(0xFF185FA5);
      case 'ESCALATED_TO_AUTHORITY':
        return const Color(0xFF854F0B);
      case 'CLOSED':
        return const Color(0xFF3B6D11);
      case 'REJECTED':
        return const Color(0xFFA32D2D);
      default:
        return Colors.black45;
    }
  }

  Color _statusBg(String? s) {
    switch (s) {
      case 'ESCALATED_TO_CC':
        return const Color(0xFFEEEDFE);
      case 'UNDER_REVIEW':
        return const Color(0xFFE6F1FB);
      case 'ESCALATED_TO_AUTHORITY':
        return const Color(0xFFFAEEDA);
      case 'CLOSED':
        return const Color(0xFFEAF3DE);
      case 'REJECTED':
        return const Color(0xFFFCEBEB);
      default:
        return const Color(0xFFF1EFE8);
    }
  }

  Color _sevColor(int level) {
    if (level >= 3) return const Color(0xFFA32D2D);
    if (level == 2) return const Color(0xFF854F0B);
    return const Color(0xFF3B6D11);
  }

  String _formatDate(String? raw) {
    if (raw == null) return '-';
    final dt = DateTime.tryParse(raw)?.toLocal();
    return dt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dt) : '-';
  }
}
