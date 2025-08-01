import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class EditStudentScreen extends StatefulWidget {
  final Map<String, dynamic> studentData;
  final String studentId;
  final String classId;

  const EditStudentScreen({
    super.key,
    required this.studentData,
    required this.studentId,
    required this.classId,
  });

  @override
  _EditStudentScreenState createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  late TextEditingController nameController;
  late TextEditingController rollNoController;
  late TextEditingController parentNameController;
  late TextEditingController addressController;
  late TextEditingController classController;

  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.studentData['name'] ?? '',
    );
    rollNoController = TextEditingController(
      text: widget.studentData['rollNo'] ?? '',
    );
    parentNameController = TextEditingController(
      text: widget.studentData['parentname'] ?? '',
    );
    addressController = TextEditingController(
      text: widget.studentData['address'] ?? '',
    );
    classController = TextEditingController(
      text: widget.studentData['class'] ?? '',
    );
  }

  Future<void> _updateStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final newName = nameController.text.trim();
    final newRollNo = rollNoController.text.trim();
    final newParent = parentNameController.text.trim();
    final newAddress = addressController.text.trim();
    final newClass = classController.text.trim();

    final oldClassName = widget.studentData['class'] ?? '';
    final oldClassId = widget.classId;

    final firestoreUserId = FirebaseAuth.instance.currentUser?.uid;
    if (firestoreUserId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in.")));
      setState(() => isLoading = false);
      return;
    }

    try {
      final usersCol = FirebaseFirestore.instance
          .collection('users')
          .doc(firestoreUserId);
      final oldStudentRef = usersCol
          .collection('classes')
          .doc(oldClassId)
          .collection('students')
          .doc(widget.studentId);

      Map<String, dynamic> baseData = {
        'name': newName,
        'rollNo': newRollNo,
        'parentname': newParent,
        'address': newAddress,
        'studentId': widget.studentId,
      };

      String targetClassId = oldClassId;
      String targetClassName = oldClassName;

      if (newClass != oldClassName) {
        final classesRef = usersCol.collection('classes');
        final snap =
            await classesRef.where('className', isEqualTo: newClass).get();

        if (snap.docs.isEmpty) {
          targetClassId = "$newClass-${const Uuid().v4()}";
          await classesRef.doc(targetClassId).set({'className': newClass});
        } else {
          targetClassId = snap.docs.first.id;
        }

        targetClassName = newClass;

        final newStudentRef = classesRef
            .doc(targetClassId)
            .collection('students')
            .doc(widget.studentId);

        await newStudentRef.set({
          ...baseData,
          'class': targetClassName,
          'classId': targetClassId,
          'qrData':
              '$newName _ $targetClassName _ $targetClassId _ ${widget.studentId}',
        });

        await oldStudentRef.delete();
      } else {
        await oldStudentRef.update({
          ...baseData,
          'class': targetClassName,
          'classId': targetClassId,
          'qrData':
              '$newName _ $targetClassName _ $targetClassId _ ${widget.studentId}',
        });
      }

      final updatedData = {
        ...baseData,
        'class': targetClassName,
        'classId': targetClassId,
        'qrData':
            '$newName _ $targetClassName _ $targetClassId _ ${widget.studentId}',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Student updated successfully.")),
      );

      Navigator.pop(context, updatedData);
    } catch (e) {
      print("❗ Update error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Student")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Name"),
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: [AutofillHints.name],
                    validator: (v) => v!.isEmpty ? "Enter name" : null,
                  ),

                  TextFormField(
                    controller: rollNoController,
                    decoration: const InputDecoration(labelText: "Roll No"),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    autofillHints: [AutofillHints.username], // closest match
                    validator: (v) => v!.isEmpty ? "Enter roll number" : null,
                  ),

                  TextFormField(
                    controller: classController,
                    decoration: const InputDecoration(labelText: "Class"),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    autofillHints: [AutofillHints.organizationName],
                    validator: (v) => v!.isEmpty ? "Enter class name" : null,
                  ),

                  TextFormField(
                    controller: parentNameController,
                    decoration: const InputDecoration(labelText: "Parent Name"),
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: [AutofillHints.name],
                    validator: (v) => v!.isEmpty ? "Enter parent name" : null,
                  ),

                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(labelText: "Address"),
                    keyboardType: TextInputType.streetAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: [AutofillHints.fullStreetAddress],
                    validator: (v) => v!.isEmpty ? "Enter address" : null,
                  ),

                  const SizedBox(height: 20),
                  if (isLoading)
                    Stack(
                      children: [Center(child: CircularProgressIndicator())],
                    )
                  else
                    ElevatedButton(
                      onPressed: _updateStudent,
                      child: const Text("Update Student"),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
