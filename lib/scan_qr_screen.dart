import 'package:attendance_app_2/scan_sound_notifier.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

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

  late MobileScannerController _scannerController;
  late AnimationController _overlayController;
  late Animation<Color?> _overlayColor;

  late AudioPlayer _audioPlayer;
  // final feedbackNotifier = Provider.of<ScanFeedbackNotifier>(context, listen: false);

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
    _audioPlayer = AudioPlayer();

    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _overlayColor = ColorTween(
      begin: Colors.black54,
      end: Colors.green.withOpacity(0.6),
    ).animate(_overlayController);
    // Access Provider after first frame is rendered
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final feedbackNotifier = Provider.of<ScanFeedbackNotifier>(context, listen: false);
    // Now you can use feedbackNotifier safely here
  });
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _overlayController.dispose();
    _audioPlayer.dispose();
    super.dispose();
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
        if (classExists) {
          bool attendanceMarked = await _markAttendance(studentId, classId);
          if (attendanceMarked) {
            if (lastScannedStudentId != studentId) {
              _onScanSuccess(studentName, studentId);
              _setOverlayColor(Colors.green.withOpacity(0.6));
              _overlayController.forward();
              await Future.delayed(const Duration(seconds: 1));
              _overlayController.reverse();
            }
          } else {
            _onScanAlready("Student already marked present! ⚠️");
            _setOverlayColor(
              Colors.deepOrange.withOpacity(0.6),
            ); // Error: Red overlay
            _overlayController.forward();
            await Future.delayed(const Duration(seconds: 1));
            _overlayController.reverse();
          }
        } else {
          _onScanError("Invalid QR Code: Class does not exist! ❌");
          _setOverlayColor(Colors.red.withOpacity(0.6)); // Error: Red overlay
          _overlayController.forward();
          await Future.delayed(const Duration(seconds: 1));
          _overlayController.reverse();
        }
      } else {
        _onScanError("Invalid QR Code! ❌");
        _setOverlayColor(Colors.red.withOpacity(0.6)); // Error: Red overlay
        _overlayController.forward();
        await Future.delayed(const Duration(seconds: 1));
        _overlayController.reverse();
      }
    } catch (e) {
      _onScanError("Error reading QR: $e");
      _setOverlayColor(Colors.red.withOpacity(0.6)); // Error: Red overlay
      _overlayController.forward();
      await Future.delayed(const Duration(seconds: 1));
      _overlayController.reverse();
    }

    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      isProcessing = false;
    });
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
    } catch (e) {
      return false;
    }
  }

  Future<void> _onScanSuccess(String studentName, String studentId) async {
    final feedbackNotifier = Provider.of<ScanFeedbackNotifier>(context, listen: false);

    setState(() {
      scannedStudentName = studentName;
      lastScannedStudentId = studentId;
      showNameOverlay = true;
    });

    // Play success sound
    if (feedbackNotifier.soundEnabled) {
      _playSound('success_ding.mp3');
    }
    if (feedbackNotifier.vibrationEnabled && await Vibration.hasVibrator()) {
  Vibration.vibrate(duration: 100);  // Vibrate for 100ms
}

    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Attendance Marked for: $studentName ✅"),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _onScanError(String message) {
    final feedbackNotifier = Provider.of<ScanFeedbackNotifier>(context, listen: false);

    setState(() {
      scannedStudentName = "";
      showNameOverlay = false;
    });
    if (feedbackNotifier.soundEnabled){
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
        duration: Duration(seconds: 1),
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
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<bool> _markAttendance(String studentId, String classId) async {
    String formattedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    DocumentReference attendanceRef = FirebaseFirestore.instance
        .collection('users')
        .doc(firestoreUserId)
        .collection('classes')
        .doc(classId)
        .collection('attendance')
        .doc(formattedDate);

    try {
      DocumentSnapshot attendanceSnapshot = await attendanceRef.get();
      if (attendanceSnapshot.exists) {
        List<String> presentStudents = List<String>.from(
          attendanceSnapshot['present'] ?? [],
        );

        if (!presentStudents.contains(studentId)) {
          presentStudents.add(studentId);
          await attendanceRef.update({'present': presentStudents});
          return true;
        } else {
          return false;
        }
      } else {
        await attendanceRef.set({
          'present': [studentId],
        });
        return true;
      }
    } catch (e) {
      return false;
    }
  }

  void _setOverlayColor(Color color) {
    _overlayColor = ColorTween(
      begin: _overlayColor.value,
      end: color,
    ).animate(_overlayController);

    _overlayController
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (capture.barcodes.isNotEmpty) {
                String qrData = capture.barcodes.first.rawValue ?? "";
                _onQrCodeScanned(qrData);
              }
            },
          ),
          _buildScannerOverlay(context),
          _buildScanFeedbackOverlay(),
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.of(context).pop(); // Go back
                  },
                ),
                const SizedBox(width: 2),
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
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                      ),
                      onPressed: () => _scannerController.switchCamera(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context) {
    return AnimatedBuilder(
      animation: _overlayColor,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // The background mask with cutout
            ColorFiltered(
              colorFilter: ColorFilter.mode(
                _overlayColor.value!,
                BlendMode.srcOut,
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: _overlayColor.value,
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

            // Layer on top: the glowing or visible corner brackets
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
    if (!showNameOverlay || scannedStudentName.isEmpty)
      return const SizedBox.shrink();

    return Positioned(
      bottom: 130,
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
