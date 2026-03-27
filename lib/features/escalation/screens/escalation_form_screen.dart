import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import '../services/escalation_api.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';

class EscalationFormScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const EscalationFormScreen({super.key, required this.event});

  @override
  ConsumerState<EscalationFormScreen> createState() =>
      _EscalationFormScreenState();
}

class _EscalationFormScreenState extends ConsumerState<EscalationFormScreen> {
  final EscalationApi api = EscalationApi();
  final TextEditingController commentController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? escalationType;
  List<File> selectedFiles = [];
  Map<String, Uint8List?> videoThumbnails = {};
  bool loading = false;
  bool showMoreDetails = false;

  // — Getters —
  String get eventId => widget.event["id"].toString();
  String get vehicleNumber => widget.event["vehicle"]["vehicleNumber"] ?? "";
  // String get driverId => widget.event["driver"]["driverId"] ?? "";
  String get driverId => widget.event["driver"]?["driverId"]?.toString() ?? "";
  String get driverDisplay {
    final first = widget.event["driver"]?["firstName"] as String? ?? "";
    final last = widget.event["driver"]?["lastName"] as String? ?? "";
    return "$first $last".trim();
  }

  String get eventStatus => widget.event["status"] as String? ?? "";
  String get eventType =>
      widget.event["details"]?["typeDescription"] as String? ?? "";
  String get eventSubType =>
      widget.event["details"]?["subTypeDescription"] as String? ?? "";
  int get severityLevel =>
      (widget.event["details"]?["severity"] as num?)?.toInt() ?? 0;
  String get severityDesc =>
      widget.event["details"]?["severityDescription"] as String? ?? "";
  double get maxVehicleSpeed =>
      (widget.event["details"]?["maxVehicleSpeed"] as num?)?.toDouble() ?? 0.0;
  double get maxGForce =>
      (widget.event["details"]?["maxGForce"] as num?)?.toDouble() ?? 0.0;
  double get confidence =>
      (widget.event["details"]?["confidence"] as num?)?.toDouble() ?? 0.0;
  String get pointOfImpact =>
      widget.event["details"]?["pointOfImpact"] as String? ?? "";
  String get weatherPrediction =>
      widget.event["details"]?["weatherPrediction"] as String? ?? "";
  String get location =>
      widget.event["details"]?["location"]?["city"] as String? ?? "";
  // String get formattedTime {
  //   final raw = widget.event["timestamp"] as String?;
  //   final ts = raw != null ? DateTime.tryParse(raw)?.toLocal() : null;
  //   return ts != null ? DateFormat('dd MMM yyyy, hh:mm a').format(ts) : "-";
  // }

  String get formattedTime {
    final ts = widget.event["timestamp"] as num?;
    if (ts == null) return "-";

    final dt = DateTime.fromMillisecondsSinceEpoch(ts.toInt()).toLocal();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  Color get severityColor {
    if (severityLevel >= 3) return const Color(0xFFA32D2D);
    if (severityLevel == 2) return const Color(0xFF854F0B);
    return const Color(0xFF3B6D11);
  }

  Color get severityBg {
    if (severityLevel >= 3) return const Color(0xFFFCEBEB);
    if (severityLevel == 2) return const Color(0xFFFAEEDA);
    return const Color(0xFFEAF3DE);
  }

  bool _isVideo(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext);
  }

  bool _isImage(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext);
  }

  Future<void> _generateThumbnail(File file) async {
    if (!_isVideo(file)) return;
    final thumb = await VideoThumbnail.thumbnailData(
      video: file.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 200,
      quality: 75,
    );
    setState(() => videoThumbnails[file.path] = thumb);
  }

  static const int _maxFileSizeMB = 10;
  static const int _maxFileSizeBytes = _maxFileSizeMB * 1024 * 1024;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: [
        'jpg',
        'jpeg',
        'png',
        'gif',
        'webp',
        'heic',
        'mp4',
        'mov',
        'avi',
        'mkv',
      ],
    );

    if (result != null) {
      final List<File> validFiles = [];
      final List<String> rejectedFiles = [];

      for (final path in result.paths) {
        final file = File(path!);
        final sizeInBytes = await file.length();

        if (sizeInBytes > _maxFileSizeBytes) {
          rejectedFiles.add(file.path.split("/").last);
        } else {
          validFiles.add(file);
        }
      }

      if (rejectedFiles.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${rejectedFiles.length} file(s) exceeded ${_maxFileSizeMB}MB limit and were not added:\n${rejectedFiles.join(', ')}",
            ),
            backgroundColor: const Color(0xFFA32D2D),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (validFiles.isNotEmpty) {
        setState(() => selectedFiles = [...selectedFiles, ...validFiles]);
        for (final f in validFiles) {
          if (_isVideo(f)) _generateThumbnail(f);
        }
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      videoThumbnails.remove(selectedFiles[index].path);
      selectedFiles.removeAt(index);
    });
  }

  double _uploadProgress = 0.0;

  Future<void> submitEscalation() async {
    if (!_formKey.currentState!.validate()) return;
    if (escalationType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an escalation type")),
      );
      return;
    }

    setState(() {
      loading = true;
      _uploadProgress = 0.0;
    });

    final data = {
      "eventId": eventId,
      "vehicleId": vehicleNumber,
      "driverId": driverId,
      "driverName": driverDisplay,
      "eventStatus": eventStatus,
      "eventType": eventType,
      "eventSubType": eventSubType,
      "severityLevel": severityLevel,
      "severityDescription": severityDesc,
      "maxVehicleSpeed": maxVehicleSpeed,
      "maxGForce": maxGForce,
      "confidence": confidence,
      "pointOfImpact": pointOfImpact,
      "weatherPrediction": weatherPrediction,
      "city": location,
      "eventTimestamp": formattedTime,
      "escalationType": escalationType,
      "comment": commentController.text,
    };

    try {
      final response = await api.createEscalation(
        data,
        selectedFiles,
        onSendProgress: (sent, total) {
          if (total > 0) setState(() => _uploadProgress = sent / total);
        },
      );

      if (response["success"] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Escalation submitted successfully")),
        );
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppConstants.routeHome,
          (r) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }

    setState(() {
      loading = false;
      _uploadProgress = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    // Defence-in-depth: ensure only permitted roles can reach this screen
    if (user != null && !user.canCreateEscalations) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Escalation')),
        body: const Center(
          child: Text(
            'You do not have permission to create escalations.',
            style: TextStyle(color: Colors.black45),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Escalate incident",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: Colors.black12),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildIncidentCard(),
            const SizedBox(height: 16),
            _buildEscalationSection(),
            const SizedBox(height: 16),
            _buildEvidenceSection(),
            const SizedBox(height: 24),
            _buildSubmitButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // — Incident Summary Card —
  Widget _buildIncidentCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eventSubType,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      eventType,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: severityBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: severityColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      severityDesc,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: severityColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.5, color: Colors.black12),
          const SizedBox(height: 14),

          // Primary info grid
          Row(
            children: [
              _infoItem("Driver", driverDisplay),
              _infoItem("Vehicle", vehicleNumber),
              _infoItem("Location", location),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _infoItem("Recorded at", formattedTime, flex: 2),
              _infoItem("Status", eventStatus),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, thickness: 0.5, color: Colors.black12),
          const SizedBox(height: 4),

          // Show more toggle
          GestureDetector(
            onTap: () => setState(() => showMoreDetails = !showMoreDetails),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    showMoreDetails ? "Show less" : "Show more details",
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF534AB7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    showMoreDetails
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF534AB7),
                  ),
                ],
              ),
            ),
          ),

          if (showMoreDetails) ...[
            const Divider(height: 1, thickness: 0.5, color: Colors.black12),
            const SizedBox(height: 14),
            _sectionLabel("Telemetry"),
            const SizedBox(height: 10),
            Row(
              children: [
                _metricTile(
                  "Max speed",
                  "${maxVehicleSpeed.toStringAsFixed(0)} km/h",
                  Icons.speed_rounded,
                ),
                const SizedBox(width: 10),
                _metricTile(
                  "Max G-force",
                  maxGForce.toStringAsFixed(2),
                  Icons.vibration_rounded,
                ),
                const SizedBox(width: 10),
                _metricTile(
                  "Confidence",
                  "${(confidence * 100).toStringAsFixed(0)}%",
                  Icons.verified_rounded,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _sectionLabel("Context"),
            const SizedBox(height: 10),
            Row(
              children: [
                _infoItem("Point of impact", pointOfImpact),
                _infoItem("Weather", weatherPrediction),
                _infoItem("Driver ID", driverId),
              ],
            ),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }

  // — Escalation Section —
  Widget _buildEscalationSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel("Escalation details"),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: escalationType,
            decoration: InputDecoration(
              labelText: "Escalation type",
              labelStyle: const TextStyle(fontSize: 13),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black12, width: 0.5),
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: "Unsafe driving behavior",
                child: Text("Unsafe driving behavior"),
              ),
              DropdownMenuItem(
                value: "Speed violation",
                child: Text("Speed violation"),
              ),
              DropdownMenuItem(
                value: "Driver distraction",
                child: Text("Driver distraction"),
              ),
              DropdownMenuItem(
                value: "Traffic rule violation",
                child: Text("Traffic rule violation"),
              ),
              DropdownMenuItem(
                value: "Fatigue / drowsiness risk",
                child: Text("Fatigue / drowsiness risk"),
              ),
              DropdownMenuItem(
                value: "Safety compliance issue",
                child: Text("Safety compliance issue"),
              ),
              DropdownMenuItem(
                value: "Potential accident risk",
                child: Text("Potential accident risk"),
              ),
              DropdownMenuItem(
                value: "Policy breach",
                child: Text("Policy breach"),
              ),
            ],
            onChanged: (v) => setState(() => escalationType = v),
            validator: (v) =>
                v == null ? "Please select an escalation type" : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: commentController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: "Comment",
              labelStyle: const TextStyle(fontSize: 13),
              hintText: "Describe the reason for escalation...",
              hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
              alignLabelWithHint: true,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.black12, width: 0.5),
              ),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? "Comment is required" : null,
          ),
        ],
      ),
    );
  }

  // — Evidence Section —
  Widget _buildEvidenceSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel("Evidence files"),
              if (selectedFiles.isNotEmpty)
                Text(
                  "${selectedFiles.length} attached",
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Attach button
          GestureDetector(
            onTap: pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
              child: Column(
                children: const [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 26,
                    color: Colors.black38,
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Tap to attach images or videos",
                    style: TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "JPG, PNG, MP4, MOV supported",
                    style: TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ],
              ),
            ),
          ),

          if (selectedFiles.isNotEmpty) ...[
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: selectedFiles.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final file = selectedFiles[index];
                final isVid = _isVideo(file);
                final isImg = _isImage(file);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: isImg
                          ? Image.file(file, fit: BoxFit.cover)
                          : isVid && videoThumbnails[file.path] != null
                          ? Image.memory(
                              videoThumbnails[file.path]!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: const Color(0xFFF1EFE8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.insert_drive_file_outlined,
                                    color: Colors.black38,
                                    size: 26,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    file.path.split('.').last.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    // Video play overlay
                    if (isVid)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    // Remove button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeFile(index),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    ),
                    // File name at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(8),
                          ),
                        ),
                        child: Text(
                          file.path.split("/").last,
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // — Submit Button —
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: loading ? null : submitEscalation,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF534AB7),
          disabledBackgroundColor: const Color(0xFF534AB7),
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: loading
            ? Stack(
                alignment: Alignment.center,
                children: [
                  // Progress fill
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      backgroundColor: const Color(0xFF3C3489),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF7B74E0),
                      ),
                      minHeight: 50,
                    ),
                  ),
                  // Label on top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _uploadProgress > 0
                            ? "Uploading... ${(_uploadProgress * 100).toInt()}%"
                            : "Submitting...",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : const Text(
                "Submit escalation",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }

  // — Helpers —
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.black45,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _infoItem(String label, String value, {int flex = 1}) {
    return Expanded(
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
  }

  Widget _metricTile(String label, String value, IconData icon) {
    return Expanded(
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
  }
}
