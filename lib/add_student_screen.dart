
import 'package:attendance_app_2/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class AddNewStudentScreen extends StatefulWidget {
  final String firestoreUserId;
  final String? prefilledClassName;
  final bool isEditing;
  final Map<String, dynamic>? studentData;
  final String? studentId;
  final String? originalClassId;

  const AddNewStudentScreen({
    super.key,
    required this.firestoreUserId,
    this.prefilledClassName,
    this.isEditing = false,
    this.studentData,
    this.studentId,
    this.originalClassId,
  });

  @override
  _AddNewStudentScreenState createState() => _AddNewStudentScreenState();
}

class _AddNewStudentScreenState extends State<AddNewStudentScreen> {
  final _formKey = GlobalKey<FormState>();

  // List to hold multiple student input controllers
  List<_StudentInputGroup> studentInputs = [];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing && widget.studentData != null) {
      final student = _StudentInputGroup();
      student.nameController.text = widget.studentData!['name'] ?? '';
      student.rollNoController.text = widget.studentData!['rollNo'] ?? '';
      student.classNameController.text = widget.studentData!['class'] ?? '';
      student.parentNameController.text =
          widget.studentData!['parentname'] ?? '';
      student.addressController.text = widget.studentData!['address'] ?? '';
      studentInputs = [student];
    } else {
      _addStudent();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (var input in studentInputs) {
      input.dispose();
    }
    super.dispose();
  }

  void _addStudent() {
    setState(() {
      studentInputs.add(
        _StudentInputGroup(prefilledClassName: widget.prefilledClassName),
      );
    });
  }

  void _removeStudent(int index) {
    setState(() {
      studentInputs[index].dispose();
      studentInputs.removeAt(index);
    });
  }

  // submit multipel students at once
  Future<void> _submitAllStudents() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final firestore = FirebaseFirestore.instance;
    final userClassesRef = firestore
        .collection('users')
        .doc(widget.firestoreUserId)
        .collection('classes');

    final batch = firestore.batch();
    final Map<String, String> classNameToId = {};
    final Set<String> duplicateCheckSet =
        {}; // rollNo_classId for avoiding duplicates

    try {
      for (var student in studentInputs) {
        final name = student.nameController.text.trim();
        final rollNo = student.rollNoController.text.trim();
        final className = student.classNameController.text.trim();
        final parent = student.parentNameController.text.trim();
        final address = student.addressController.text.trim();

        // Skip empty entries (optional safety)
        if ([name, rollNo, className].any((val) => val.isEmpty)) continue;

        // Check if class already fetched
        String classId;
        if (classNameToId.containsKey(className)) {
          classId = classNameToId[className]!;
        } else {
          final classQuery =
              await userClassesRef
                  .where('className', isEqualTo: className)
                  .limit(1)
                  .get();

          if (classQuery.docs.isEmpty) {
            classId = "$className-${const Uuid().v4()}";
            classNameToId[className] = classId;

            // Add new class to batch
            final newClassRef = userClassesRef.doc(classId);
            batch.set(newClassRef, {'className': className});
          } else {
            classId = classQuery.docs.first.id;
            classNameToId[className] = classId;
          }
        }

        // Check for duplicate rollNo within same class
        String uniqueKey = "$rollNo|$classId";
        if (duplicateCheckSet.contains(uniqueKey)) {
          // skip this student or show message
          continue;
        }
        duplicateCheckSet.add(uniqueKey);

        final studentId = const Uuid().v4();
        final studentDocRef = userClassesRef
            .doc(classId)
            .collection('students')
            .doc(studentId);

        batch.set(studentDocRef, {
          'name': name,
          'rollNo': rollNo,
          'class': className,
          'classId': classId,
          'parentname': parent,
          'address': address,
          'studentId': studentId,
          'qrData': '$name _ $className _ $classId _ $studentId',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All students added successfully!")),
      );

      Navigator.pop(context); // or reset form
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitEditStudent() async {
    final form = studentInputs.first;

    final name = form.nameController.text.trim();
    final rollNo = form.rollNoController.text.trim();
    final className = form.classNameController.text.trim();
    final parent = form.parentNameController.text.trim();
    final address = form.addressController.text.trim();
    final studentId = widget.studentId!;
    final oldClassId = widget.originalClassId!;

    setState(() => isLoading = true);

    final classesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.firestoreUserId)
        .collection('classes');

    try {
      QuerySnapshot classSnap =
          await classesRef.where('className', isEqualTo: className).get();

      String classId =
          classSnap.docs.isEmpty
              ? "$className-${const Uuid().v4()}"
              : classSnap.docs.first.id;

      if (classSnap.docs.isEmpty) {
        await classesRef.doc(classId).set({'className': className});
      }

      final studentData = {
        'name': name,
        'rollNo': rollNo,
        'class': className,
        'classId': classId,
        'parentname': parent,
        'address': address,
        'studentId': studentId,
        'qrData': '$name _ $className _ $classId _ $studentId',
      };

      if (classId != oldClassId) {
        await classesRef
            .doc(oldClassId)
            .collection('students')
            .doc(studentId)
            .delete();
        await classesRef
            .doc(classId)
            .collection('students')
            .doc(studentId)
            .set(studentData);
      } else {
        await classesRef
            .doc(classId)
            .collection('students')
            .doc(studentId)
            .update(studentData);
      }

      Navigator.pop(context, studentData);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor:
                themeNotifier.isDarkMode
                    ? Colors.blue.shade900
                    : Colors.blue.shade700,
            title: Text(
              widget.isEditing ? "Edit Student" : "Add New Students",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
            ),
            elevation: 4,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // For each student input group, build the UI
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: studentInputs.length,
                    itemBuilder: (context, index) {
                      final input = studentInputs[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Student ${index + 1}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  if (!widget.isEditing &&
                                      studentInputs.length > 1)
                                    IconButton(
                                      onPressed: () => _removeStudent(index),
                                      icon: const Icon(
                                        Icons.remove_circle,
                                        color: Colors.red,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildTextFormField(
                                input.nameController,
                                "Name",
                                themeNotifier,
                              ),
                              const SizedBox(height: 8),
                              _buildTextFormField(
                                input.rollNoController,
                                "Roll No.",
                                themeNotifier,
                                inputType: TextInputType.number,
                              ),
                              const SizedBox(height: 8),
                              widget.prefilledClassName != null
                                  ? _buildReadOnlyField(
                                    input.classNameController,
                                    "Class",
                                    themeNotifier,
                                  )
                                  : _buildTextFormField(
                                    input.classNameController,
                                    "Class",
                                    themeNotifier,
                                  ),
                              const SizedBox(height: 8),
                              _buildTextFormField(
                                input.parentNameController,
                                "Parent Name",
                                themeNotifier,
                              ),
                              const SizedBox(height: 8),
                              _buildTextFormField(
                                input.addressController,
                                "Address",
                                themeNotifier,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  if (!widget.isEditing)
                    ElevatedButton.icon(
                      onPressed: _addStudent,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text(
                        "Add Student",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            themeNotifier.isDarkMode
                                ? const Color.fromARGB(255, 4, 158, 145)
                                : const Color.fromARGB(255, 76, 168, 175),
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 24,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                  isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            if (widget.isEditing) {
                              _submitEditStudent(); // implement this
                            } else {
                              _submitAllStudents();
                            }
                          }
                        },

                        style: ElevatedButton.styleFrom(
                          elevation: 4,
                          backgroundColor:
                              themeNotifier.isDarkMode
                                  ? Colors.blue.shade600
                                  : Colors.blueAccent,
                          padding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          shadowColor: Colors.black45,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.person_add,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isEditing
                                  ? "Update Student"
                                  : "Submit All Students",
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextFormField(
    TextEditingController controller,
    String labelText,
    ThemeNotifier themeNotifier, {
    TextInputType inputType = TextInputType.text,
  }) {
    return Card(
      elevation: 2,
      shadowColor:
          themeNotifier.isDarkMode
              ? Colors.blue.shade800
              : Colors.blue.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          labelText: labelText,
          labelStyle: TextStyle(
            color: themeNotifier.isDarkMode ? Colors.white : Colors.black87,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator:
            (value) =>
                value == null || value.isEmpty ? "Enter $labelText" : null,
      ),
    );
  }

  Widget _buildReadOnlyField(
    TextEditingController controller,
    String labelText,
    ThemeNotifier themeNotifier,
  ) {
    return Card(
      elevation: 2,
      shadowColor:
          themeNotifier.isDarkMode
              ? Colors.blue.shade800
              : Colors.blue.shade200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          labelText: "$labelText (Pre-filled)",
          labelStyle: TextStyle(
            color: themeNotifier.isDarkMode ? Colors.white : Colors.black87,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  themeNotifier.isDarkMode
                      ? Colors.blue.shade300
                      : Colors.blue.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color:
                  themeNotifier.isDarkMode
                      ? Colors.blue.shade300
                      : Colors.blue.shade300,
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentInputGroup {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController rollNoController = TextEditingController();
  final TextEditingController classNameController = TextEditingController();
  final TextEditingController parentNameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  _StudentInputGroup({String? prefilledClassName}) {
    if (prefilledClassName != null) {
      classNameController.text = prefilledClassName;
    }
  }

  void dispose() {
    nameController.dispose();
    rollNoController.dispose();
    classNameController.dispose();
    parentNameController.dispose();
    addressController.dispose();
  }
}
