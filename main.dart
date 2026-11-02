import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const StudentFirestoreApp());
}

class StudentFirestoreApp extends StatelessWidget {
  const StudentFirestoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Records - Firestore',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const StudentHomePage(),
    );
  }
}

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  State<StudentHomePage> createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _departmentController = TextEditingController();
  final _marksController = TextEditingController();

  final CollectionReference<Map<String, dynamic>> _students =
      FirebaseFirestore.instance.collection('students');

  bool _isSaving = false;

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final registrationNumber = _regNoController.text.trim().toUpperCase();
      // Registration number is the document ID -> no duplicate records.
      await _students.doc(registrationNumber).set({
        'name': _nameController.text.trim(),
        'registrationNumber': registrationNumber,
        'department': _departmentController.text.trim(),
        'marks': double.parse(_marksController.text.trim()),
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _nameController.clear();
      _regNoController.clear();
      _departmentController.clear();
      _marksController.clear();
      _showMessage('Student record saved successfully!');
    } catch (error) {
      if (!mounted) return;
      _showMessage('Error saving student: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _regNoController.dispose();
    _departmentController.dispose();
    _marksController.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController c, String label, IconData icon,
      String? Function(String?) validator,
      {TextInputType? keyboardType}) {
    return TextFormField(
      controller: c,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
      validator: validator,
    );
  }

  String? _required(String? v, String msg) =>
      (v == null || v.trim().isEmpty) ? msg : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Records- Firestore',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 850),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Enter Student Details',
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        _field(_nameController, 'Student Name', Icons.person,
                            (v) => _required(v, 'Please enter student name')),
                        const SizedBox(height: 15),
                        _field(_regNoController, 'Registration Number',
                            Icons.badge,
                            (v) => _required(
                                v, 'Please enter registration number')),
                        const SizedBox(height: 15),
                        _field(_departmentController, 'Department',
                            Icons.school,
                            (v) => _required(v, 'Please enter department')),
                        const SizedBox(height: 15),
                        _field(
                          _marksController,
                          'Marks (0–100)',
                          Icons.grade,
                          (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter marks';
                            }
                            final m = double.tryParse(v.trim());
                            if (m == null || m < 0 || m > 100) {
                              return 'Enter marks between 0 and 100';
                            }
                            return null;
                          },
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveStudent,
                          icon: _isSaving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.cloud_upload),
                          label: Text(_isSaving
                              ? 'Saving...'
                              : 'Save Student to Firestore'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              const Text('Saved Student Records',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // READ: StreamBuilder updates the list when Firestore changes.
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _students.orderBy('registrationNumber').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child:
                            Text('Error loading records: ${snapshot.error}'),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final documents = snapshot.data?.docs ?? [];
                  if (documents.isEmpty) {
                    return const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: Text('No student records found. '
                              'Add a student using the form above.'),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: documents.map((document) {
                      final student = document.data();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                            child: Icon(Icons.person),
                          ),
                          title: Text(student['name']?.toString() ?? '',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                'Registration No: ${student['registrationNumber'] ?? ''}\n'
                                'Department: ${student['department'] ?? ''}\n'
                                'Marks: ${student['marks'] ?? ''}'),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
