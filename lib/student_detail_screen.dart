import 'dart:ui';

import 'package:attendance_app_2/add_student_screen.dart';
import 'package:attendance_app_2/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:open_file/open_file.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_path/external_path.dart';

class StudentDetailScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final String firestoreUserId; // You need this to pass to AddNewStudentScreen

  const StudentDetailScreen({
    super.key,
    required this.studentData,
    required this.firestoreUserId,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late Map<String, dynamic> studentData;

  @override
  void initState() {
    super.initState();
    studentData = Map<String, dynamic>.from(widget.studentData);
  }

  void _navigateToEditScreen() async {
    final updatedStudentData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddNewStudentScreen(
              firestoreUserId: widget.firestoreUserId,
              isEditing: true,
              studentData: studentData,
              studentId: studentData['studentId'],
              originalClassId: studentData['classId'],
            ),
      ),
    );

    if (updatedStudentData != null) {
      setState(() {
        studentData = Map<String, dynamic>.from(updatedStudentData);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student info updated!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // void _showFullScreenQR(
  //   BuildContext context,
  //   Map<String, dynamic> studentData,
  // ) {
  //   final theme = Theme.of(context);
  //   final isDark = theme.brightness == Brightness.dark;
  //   final GlobalKey qrKey = GlobalKey();

  //   showDialog(
  //     context: context,
  //     barrierDismissible: true,
  //     builder:
  //         (_) => Dialog(
  //           shape: RoundedRectangleBorder(
  //             borderRadius: BorderRadius.circular(16),
  //           ),
  //           backgroundColor: theme.dialogBackgroundColor,
  //           child: Stack(
  //             children: [
  //               Padding(
  //                 padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
  //                 child: Column(
  //                   mainAxisSize: MainAxisSize.min,
  //                   children: [
  //                     Text(
  //                       "QR Code for ${studentData['name'] ?? 'Unknown'}",
  //                       textAlign: TextAlign.center,
  //                       style: theme.textTheme.titleLarge?.copyWith(
  //                         fontWeight: FontWeight.bold,
  //                       ),
  //                     ),
  //                     const SizedBox(height: 24),

  //                     RepaintBoundary(
  //                       key: qrKey,
  //                       child: Container(
  //                         decoration: BoxDecoration(
  //                           color:
  //                               Colors
  //                                   .white, // white background for all, including text
  //                           borderRadius: BorderRadius.circular(16),
  //                           border: Border.all(color: Colors.grey.shade300),
  //                           boxShadow:
  //                               isDark
  //                                   ? null
  //                                   : [
  //                                     BoxShadow(
  //                                       color: Colors.black.withOpacity(0.05),
  //                                       blurRadius: 10,
  //                                       offset: const Offset(0, 6),
  //                                     ),
  //                                   ],
  //                         ),
  //                         padding: const EdgeInsets.all(16),
  //                         child: Column(
  //                           mainAxisSize: MainAxisSize.min,
  //                           children: [
  //                             Text(
  //                               studentData['name'] ?? 'Unknown',
  //                               textAlign: TextAlign.center,
  //                               style: theme.textTheme.titleLarge?.copyWith(
  //                                 fontWeight: FontWeight.bold,
  //                                 color: Colors.black, // black text on white bg
  //                               ),
  //                             ),
  //                             const SizedBox(height: 12),
  //                             Stack(
  //                               alignment: Alignment.center,
  //                               children: [
  //                                 QrImageView(
  //                                   data: studentData['qrData'] ?? 'No QR Data',
  //                                   version: QrVersions.auto,
  //                                   size: 200,
  //                                   backgroundColor: Colors.white,
  //                                   gapless: false,
  //                                 ),
  //                                 CircleAvatar(
  //                                   radius: 20,
  //                                   backgroundColor: Colors.white,
  //                                   child: OverflowBox(
  //                                     maxHeight: 60,
  //                                     maxWidth: 60,
  //                                     child: ClipOval(
  //                                       child: Image.asset(
  //                                         'assets/app_logo.png',
  //                                         width: 60,
  //                                         height: 60,
  //                                         fit: BoxFit.cover,
  //                                       ),
  //                                     ),
  //                                   ),
  //                                 ),
  //                               ],
  //                             ),
  //                           ],
  //                         ),
  //                       ),
  //                     ),

  //                     const SizedBox(height: 24),
  //                     ElevatedButton.icon(
  //                       onPressed: () async {
  //                         final result = await _downloadQR(
  //                           context: context,
  //                           key: qrKey,
  //                           studentName: studentData['name'] ?? 'Unknown',
  //                           className: studentData['class'] ?? 'UnknownClass',
  //                         );
  //                         if (result.success) {
  //                           Navigator.of(context).pop();

  //                           ScaffoldMessenger.of(context).showSnackBar(
  //                             SnackBar(
  //                               content: GestureDetector(
  //                                 onTap: () async {
  //                                   final file = File(result.filePath!);
  //                                   if (await file.exists()) {
  //                                     OpenFile.open(result.filePath!);
  //                                   }
  //                                 },
  //                                 child: Text(
  //                                   'QR saved! Tap to open.',
  //                                   style: const TextStyle(
  //                                     // decoration: TextDecoration.underline,
  //                                     color: Colors.white,
  //                                   ),
  //                                 ),
  //                               ),
  //                               backgroundColor: Colors.green,
  //                               duration: const Duration(seconds: 5),
  //                             ),
  //                           );
  //                         } else {
  //                           ScaffoldMessenger.of(context).showSnackBar(
  //                             SnackBar(
  //                               content: Text(
  //                                 result.message ?? 'Failed to save QR',
  //                               ),
  //                               backgroundColor: Colors.red,
  //                               duration: const Duration(seconds: 5),
  //                             ),
  //                           );
  //                         }
  //                       },
  //                       icon: const Icon(Icons.download),
  //                       label: const Text("Download QR Code"),
  //                       style: ElevatedButton.styleFrom(
  //                         backgroundColor: theme.colorScheme.primary,
  //                         foregroundColor: theme.colorScheme.onPrimary,
  //                         padding: const EdgeInsets.symmetric(
  //                           horizontal: 24,
  //                           vertical: 14,
  //                         ),
  //                         textStyle: const TextStyle(fontSize: 16),
  //                         shape: RoundedRectangleBorder(
  //                           borderRadius: BorderRadius.circular(10),
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //               Positioned(
  //                 top: 8,
  //                 right: 8,
  //                 child: IconButton(
  //                   icon: Icon(Icons.close, color: theme.iconTheme.color),
  //                   onPressed: () => Navigator.of(context).pop(),
  //                   tooltip: "Close",
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //   );
  // }

  Future<DownloadResult> _downloadQR({
    required BuildContext context,
    required GlobalKey key,
    required String studentName,
    required String className,
  }) async {
    try {
      // Request permission
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        if (!status.isGranted) {
          if (status.isPermanentlyDenied) openAppSettings();
          return DownloadResult(
            success: false,
            message: 'Storage permission is required.',
          );
        }
      }

      // Capture QR as image
      RenderRepaintBoundary boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      var image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Build path: Downloads/AttendanceApp/ClassName/
      final downloadsPath =
          await ExternalPath.getExternalStoragePublicDirectory(
            ExternalPath.DIRECTORY_DOWNLOAD,
          );

      String sanitizedClassName = className.replaceAll(' ', '_');
      String sanitizedStudentName = studentName.replaceAll(' ', '_');

      final directory = Directory(
        '$downloadsPath/AttendanceApp/Class_$sanitizedClassName',
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Create file
      final filePath = '${directory.path}/QR_$sanitizedStudentName.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      return DownloadResult(success: true, filePath: filePath);
    } catch (e) {
      return DownloadResult(success: false, message: 'Failed to save QR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final GlobalKey qrKey = GlobalKey();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Student Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor:
            themeNotifier.isDarkMode ? Colors.blue.shade900 : Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: "Edit Student",
            onPressed: _navigateToEditScreen,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetail("Name", studentData['name'], textColor),
              _buildDetail("Class", studentData['class'], textColor),
              _buildDetail("Roll No", studentData['rollNo'], textColor),
              _buildDetail("Parent Name", studentData['parentname'], textColor),
              _buildDetail("Address", studentData['address'] ?? "-", textColor),
              const SizedBox(height: 30),
              Center(
                child: Column(
                  children: [
                    const Text(
                      "QR Code",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RepaintBoundary(
                      key: qrKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 4),
                            ),
                          ],
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Text(
                              studentData['name'] ?? "Unknown",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                QrImageView(
                                  data: studentData['qrData'] ?? 'no QR Data',
                                  version: QrVersions.auto,
                                  size: 200,
                                  backgroundColor: Colors.white,
                                  gapless: false,
                                ),
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.white,
                                  child: OverflowBox(
                                    maxHeight: 60,
                                    maxWidth: 60,
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/app_logo.png',
                                        width: 60,
                                        height: 60,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final result = await _downloadQR(
                          context: context,
                          key: qrKey,
                          studentName: studentData['name'] ?? 'Unknown',
                          className: studentData['class'] ?? 'UnknownClass',
                        );
                        if (result.success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: GestureDetector(
                                onTap: () async {
                                  final file = File(result.filePath!);
                                  if (await file.exists()) {
                                    OpenFile.open(result.filePath!);
                                  }
                                },
                                child: const Text(
                                  'QR saved! Tap to open.',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.message ?? 'Failed to save QR',
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text("Download QR Code"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Scan this QR code to mark attendance for "${studentData['name']}"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetail(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontSize: 18, color: color)),
          ),
        ],
      ),
    );
  }
}

class DownloadResult {
  final bool success;
  final String? filePath;
  final String? message;

  DownloadResult({required this.success, this.filePath, this.message});
}
