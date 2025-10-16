import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendance_app_2/scan_sound_notifier.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  _ScanScreenState createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  final String firestoreUserId = FirebaseAuth.instance.currentUser!.uid;
  bool isProcessing = false;
  String scannedStudentName = "";
  String lastScannedStudentId = "";
  bool showNameOverlay = false;
  bool isTorchOn = false;
  Set<String> scannedStudentIds = {};
  Map<String, Set<String>> _attendanceCache = {};
  bool isSaving = false;

  late MobileScannerController _scannerController;
  late AnimationController _overlayController;
  late Animation<Color?> _overlayColor;
  late AudioPlayer _audioPlayer;
  Color _currentOverlayColor = Colors.transparent;

  final GlobalKey _cameraKey = GlobalKey();
  ui.Image? _capturedFrame;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _audioPlayer = AudioPlayer();

    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _overlayColor = ColorTween(
      begin: Colors.black54,
      end: _currentOverlayColor,
    ).animate(_overlayController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scannerController.start();
    });
  }

  @override
  void dispose() {
    scannedStudentIds.clear();
    _attendanceCache.clear();
    _scannerController.dispose();
    _overlayController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }



Future<void> saveAttendanceCache() async {
  final prefs = await SharedPreferences.getInstance();
  // convert Set<String> to List<String> before encoding
  final encoded = _attendanceCache.map((key, value) =>
    MapEntry(key, value.toList()));
  prefs.setString('attendance_cache', jsonEncode(encoded));
}

Future<void> loadAttendanceCache() async {
  final prefs = await SharedPreferences.getInstance();
  final jsonString = prefs.getString('attendance_cache');
  if (jsonString != null) {
    final Map<String, dynamic> decoded = jsonDecode(jsonString);
    _attendanceCache = decoded.map((key, value) =>
      MapEntry(key, Set<String>.from(value)));
  } else {
    _attendanceCache = {};
  }
}

  Future<void> _playSound(String fileName) async {
    await _audioPlayer.play(AssetSource(fileName));
  }

  void _onQrCodeScanned(String qrData) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      List<String> qrParts = qrData.split(" _ ");
      if (qrParts.length == 4) {
        String studentName = qrParts[0];
        String studentId = qrParts[3];
        String classId = qrParts[2];

        bool classExists = await _checkClassExists(classId);
        if (!classExists) {
          await _showOverlay(
            Colors.red.withOpacity(0.6),
            message: "Class does not exist ❌",
            isError: true,
          );
        } else {
          bool markedLocally = _markAttendanceLocally(studentId, classId);
          if (markedLocally) {
            _onScanSuccess(studentName, studentId);
            await _showOverlay(Colors.green.withOpacity(0.6));
          } else {
            await _showOverlay(
              Colors.orange.withOpacity(0.6),
              message: "Student already marked present! ⚠️",
              isError: false,
            );
          }
        }
      } else {
        await _showOverlay(
          Colors.red.withOpacity(0.6),
          message: "Invalid QR Code ❌",
          isError: true,
        );
      }
    } catch (e) {
      await _showOverlay(
        Colors.red.withOpacity(0.6),
        message: "Error reading QR: $e",
        isError: true,
      );
    }

    setState(() {
      isProcessing = false;
    });
  }

  Future<void> _showOverlay(
    Color color, {
    String? message,
    bool isError = false,
  }) async {
    await _captureFreezeFrame();

    if (message != null) {
      if (isError) {
        _onScanError(message);
      } else {
        _onScanAlready(message);
      }
    }

    setState(() {
      _currentOverlayColor = color;
    });

    await _overlayController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    await _overlayController.reverse();
    _clearFreezeFrame();
  }

  Future<void> _captureFreezeFrame() async {
    try {
      RenderRepaintBoundary boundary =
          _cameraKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(
        pixelRatio: ui.window.devicePixelRatio,
      );
      setState(() {
        _capturedFrame = image;
      });
    } catch (e) {
      debugPrint("Freeze frame error: $e");
    }
  }

  Future<bool> _checkClassExists(String classId) async {
    try {
      DocumentSnapshot classSnapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(firestoreUserId)
              .collection('classes')
              .doc(classId)
              .get();
      return classSnapshot.exists;
    } catch (_) {
      return false;
    }
  }

  // Change _markAttendance to only update local cache, no firestore write here
  bool _markAttendanceLocally(String studentId, String classId) {
  if (!_attendanceCache.containsKey(classId)) {
    _attendanceCache[classId] = <String>{};
  }
  if (_attendanceCache[classId]!.contains(studentId)) {
    return false; // already present
  }
  _attendanceCache[classId]!.add(studentId);
  saveAttendanceCache(); // save after update
  return true;
}

  // New method: batch write all cached attendance to firestore
  Future<bool> _batchWriteAttendance() async {
  setState(() {
    isSaving = true;
  });

  try {
    final batch = FirebaseFirestore.instance.batch();
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var classId in _attendanceCache.keys) {
      final studentSet = _attendanceCache[classId]!;

      final attendanceRef = FirebaseFirestore.instance
          .collection('users')
          .doc(firestoreUserId)
          .collection('classes')
          .doc(classId)
          .collection('attendance')
          .doc(formattedDate);

      final existingDoc = await attendanceRef.get();
      List<dynamic> existingPresent = [];

      if (existingDoc.exists) {
        existingPresent = (existingDoc.data()?['present'] ?? []) as List<dynamic>;
      }

      // Merge existing + current
      final mergedSet = {...existingPresent.map((e) => e.toString()), ...studentSet};

      batch.set(attendanceRef, {
        'present': mergedSet.toList(),
      }, SetOptions(merge: true));
    }

    await batch.commit();

    setState(() {
      isSaving = false;
    });
    return true;
  } catch (e) {
    setState(() {
      isSaving = false;
    });
    debugPrint("Batch write failed: $e");
    return false;
  }
}


  // Override back button (or screen pop) to auto save pending attendance
  Future<bool> _onWillPop() async {
    if (_attendanceCache.isNotEmpty) {
      bool success = await _batchWriteAttendance();
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to save attendance before exit. Please try again.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false; // Prevent exit to retry save
      }
    }
    return true; // Allow exit
  }

  Future<void> _onScanSuccess(String studentName, String studentId) async {
    final feedbackNotifier = Provider.of<ScanFeedbackNotifier>(
      context,
      listen: false,
    );

    setState(() {
      scannedStudentName = studentName;
      lastScannedStudentId = studentId;
      showNameOverlay = true;
    });

    if (feedbackNotifier.soundEnabled) {
      _playSound('success_ding.mp3');
    }
    if (feedbackNotifier.vibrationEnabled && await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 100);
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Attendance Marked for: $studentName ✅"),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onScanAlready(String message) {
    setState(() {
      scannedStudentName = "";
      showNameOverlay = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _onScanError(String message) {
    final feedbackNotifier = Provider.of<ScanFeedbackNotifier>(
      context,
      listen: false,
    );

    setState(() {
      scannedStudentName = "";
      showNameOverlay = false;
    });

    if (feedbackNotifier.soundEnabled) {
      _playSound('error.mp3');
    }
    if (feedbackNotifier.vibrationEnabled) {
      Vibration.vibrate(duration: 100);
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _clearFreezeFrame() {
    setState(() {
      _capturedFrame = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // intercept back press to save
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            RepaintBoundary(
              key: _cameraKey,
              child: MobileScanner(
                controller: _scannerController,
                onDetect: (capture) {
                  if (capture.barcodes.isNotEmpty) {
                    String qrData = capture.barcodes.first.rawValue ?? "";
                    _onQrCodeScanned(qrData);
                  }
                },
              ),
            ),
            _buildFreezeFrame(),
            _buildScannerOverlay(),
            _buildScanFeedbackOverlay(),
            _buildTopBar(),
            // Positioned below scan box
            Positioned(
              bottom: 150, // adjust as needed
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  onPressed:
                      isSaving
                          ? null
                          : () async {
                            if (_attendanceCache.isEmpty) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('No attendance to save.'),
                                  backgroundColor: Colors.orange,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              Navigator.pop(context);
                              return;
                            }

                            bool success = await _batchWriteAttendance();
                            if (success) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Attendance saved successfully!',
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              _attendanceCache.clear();

                              // ✅ Pop screen after short delay (to let snackbar show)
                              await Future.delayed(
                                const Duration(milliseconds: 300),
                              );
                              if (context.mounted) Navigator.of(context).pop();
                            } else {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to save attendance.'),
                                  backgroundColor: Colors.red,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                  child: const Text('Done'),
                ),
              ),
            ),

            if (isSaving)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 40,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              bool canPop = await _onWillPop();
              if (canPop) Navigator.of(context).pop();
            },
          ),
          const Text(
            "Scan QR Code",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await _scannerController.toggleTorch();
                  setState(() {
                    isTorchOn = !isTorchOn;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                onPressed: () => _scannerController.switchCamera(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFreezeFrame() {
    if (_capturedFrame == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: RawImage(
          image: _capturedFrame,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }

  Widget _buildScannerOverlay() {
    return AnimatedBuilder(
      animation: _overlayColor,
      builder: (context, child) {
        final color = Color.lerp(
          Colors.transparent,
          _currentOverlayColor,
          _overlayController.value,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                color ?? Colors.transparent,
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: color,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.qr_code_scanner,
                          color: Colors.black45,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  children: [
                    Positioned(top: 0, left: 0, child: _buildCurvedCorner()),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: _buildCurvedCorner(rotate: 90),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _buildCurvedCorner(rotate: 180),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: _buildCurvedCorner(rotate: 270),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurvedCorner({double rotate = 0}) {
    return Transform.rotate(
      angle: rotate * 3.1416 / 180,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
          border: const Border(
            top: BorderSide(width: 4, color: Colors.cyanAccent),
            left: BorderSide(width: 4, color: Colors.cyanAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildScanFeedbackOverlay() {
    if (!showNameOverlay || scannedStudentName.isEmpty) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 130,
      left: 20,
      right: 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.tealAccent.shade200,
                Colors.deepPurpleAccent.shade200,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle, size: 32, color: Colors.white),
              const SizedBox(height: 8),
              const Text(
                "Attendance Marked",
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                scannedStudentName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
