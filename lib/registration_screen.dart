import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'assessment_screen.dart';
import 'database_helper.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int currentSubStep = 0;

  final _nameController = TextEditingController();
  final _identityController = TextEditingController();
  final _otpController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  String selectedImagePath = "";
  Uint8List? webImageBytes;

  bool hasMinLength = false;
  bool hasCapital = false;
  bool hasDigit = false;
  bool hasSpecial = false;

  String? _generatedOTP;

  @override
  void initState() {
    super.initState();
    _passController.addListener(_checkPasswordRules);
  }

  @override
  void dispose() {
    _passController.removeListener(_checkPasswordRules);
    _nameController.dispose();
    _identityController.dispose();
    _otpController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          webImageBytes = bytes;
          selectedImagePath = pickedFile.path;
        });
      } else {
        setState(() {
          selectedImagePath = File(pickedFile.path).absolute.path;
        });
      }
    }
  }

  void _checkPasswordRules() {
    String pass = _passController.text;
    setState(() {
      hasMinLength = pass.length >= 5;
      hasCapital = pass.contains(RegExp(r'[A-Z]'));
      hasDigit = pass.contains(RegExp(r'[0-9]'));
      hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isValidEmail(String input) => RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(input);
  bool _isValidPhone(String input) => input.length == 10 && int.tryParse(input) != null;

  void _moveToOTP() {
    // 👈 ശ്രദ്ധിക്കുക: ഇവിടെ നിന്നും Autofill സബ്മിറ്റ് ചെയ്യുന്നത് ഒഴിവാക്കി.
    // അവസാന സ്റ്റെപ്പിൽ മാത്രമേ പാസ്‌വേഡ് സേവ് ചെയ്യാൻ പാടുള്ളൂ.

    if (_nameController.text.trim().isEmpty) {
      _showSnackBar("Please enter your Full Name");
      return;
    }
    String input = _identityController.text.trim();
    if (!_isValidEmail(input) && !_isValidPhone(input)) {
      _showSnackBar("Enter a valid Email or 10-digit Phone");
      return;
    }

    _generatedOTP = (1000 + Random().nextInt(9000)).toString();

    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("OTP Sent successfully! Your Test Code is: $_generatedOTP", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 6),
        )
    );

    setState(() => currentSubStep = 1);
  }

  void _verifyOTP() {
    if (_otpController.text.trim() != _generatedOTP) {
      _showSnackBar("Invalid OTP! Please check the code and try again.");
      return;
    }
    setState(() => currentSubStep = 2);
  }

  void _finalizePassword() async {
    // 👈 🌟 FIXED: ഇവിടെ പാസ്‌വേഡ് സബ്മിറ്റ് ചെയ്യുമ്പോൾ മാത്രം Autofill ലോക്ക് ചെയ്യുന്നു
    // ഇപ്പോൾ യൂസർനെയിമും പാസ്‌വേഡും ഒരുമിച്ച് ഗൂഗിളിന് ലഭിക്കും!
    TextInput.finishAutofillContext();

    if (!hasMinLength || !hasCapital || !hasDigit || !hasSpecial) {
      _showSnackBar("Please fulfill all password requirements!");
      return;
    }
    if (_passController.text != _confirmPassController.text) {
      _showSnackBar("Passwords do not match!");
      return;
    }

    // Save to local database
    await DatabaseHelper.saveUserData(
      _nameController.text.trim(),
      _identityController.text.trim(),
      _passController.text,
      selectedImagePath,
    );

    // Admin Sync
    try {
      final prefs = await SharedPreferences.getInstance();
      String? existingUsersRaw = prefs.getString('all_registered_users');
      List<dynamic> allUsers = existingUsersRaw != null ? jsonDecode(existingUsersRaw) : [];

      String email = _identityController.text.trim();
      bool userExists = allUsers.any((u) => u['email'] == email);

      if (!userExists) {
        allUsers.add({
          'name': _nameController.text.trim(),
          'email': email,
          'avatar': selectedImagePath,
          'last_login': 'Just Registered'
        });
        await prefs.setString('all_registered_users', jsonEncode(allUsers));
      }
    } catch (e) {
      debugPrint("Admin Sync Error: $e");
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AssessmentScreen(
          registeredName: _nameController.text.trim(),
          chosenAvatar: selectedImagePath,
          registeredEmail: _identityController.text.trim(),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  Widget _buildRuleText(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(isMet ? Icons.check_circle : Icons.cancel, color: isMet ? Colors.green : Colors.red, size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: isMet ? Colors.green : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (currentSubStep > 0) setState(() => currentSubStep--);
        else Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(title: const Text("Setup Account"), backgroundColor: Colors.transparent, elevation: 0),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              // 👈 🌟 NEW: ഒരൊറ്റ AutofillGroup വെച്ച് എല്ലാ ഫീൽഡുകളെയും പരസ്പരം ബന്ധിപ്പിച്ചു!
              child: AutofillGroup(
                // 👈 🌟 NEW: IndexedStack ഉപയോഗിച്ചതുകൊണ്ട് പഴയ സ്റ്റെപ്പുകൾ ഹൈഡ് ആയാലും Chrome-ന് ഡാറ്റ കാണാൻ പറ്റും.
                child: IndexedStack(
                  index: currentSubStep,
                  children: [
                    _buildRegSubStep(),
                    _buildOtpSubStep(),
                    _buildPasswordSubStep(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegSubStep() {
    return Column(
      children: [
        GestureDetector(
          onTap: _pickProfileImage,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                backgroundImage: selectedImagePath.isNotEmpty && !kIsWeb
                    ? FileImage(File(selectedImagePath))
                    : null,
                child: selectedImagePath.isEmpty
                    ? const Icon(Icons.person, size: 60, color: Colors.teal)
                    : (kIsWeb && webImageBytes != null
                    ? ClipOval(child: Image.memory(webImageBytes!, width: 120, height: 120, fit: BoxFit.cover))
                    : null),
              ),
              const CircleAvatar(
                radius: 18,
                backgroundColor: Colors.teal,
                child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _pickProfileImage,
          child: const Text("UPLOAD PROFILE IMAGE", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),

        TextField(
            controller: _nameController,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder())
        ),
        const SizedBox(height: 16),

        TextField(
            controller: _identityController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            // 👈 🌟 NEW: AutofillHints.username നിർബന്ധമായും ആഡ് ചെയ്തു
            autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber, AutofillHints.username],
            decoration: const InputDecoration(labelText: "Email or Phone Number", border: OutlineInputBorder())
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _moveToOTP, child: const Text("Send Verification Code"))
      ],
    );
  }

  Widget _buildOtpSubStep() {
    return Column(
      children: [
        const Icon(Icons.mark_email_read_rounded, size: 64, color: Colors.teal),
        const SizedBox(height: 24),
        TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, letterSpacing: 10),
            decoration: const InputDecoration(labelText: "Enter 4-Digit OTP", border: OutlineInputBorder())
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _verifyOTP, child: const Text("Verify & Proceed"))
      ],
    );
  }

  Widget _buildPasswordSubStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
            controller: _passController,
            obscureText: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: "New Password", border: OutlineInputBorder())
        ),
        const SizedBox(height: 8),
        _buildRuleText("At least 5 characters long", hasMinLength),
        _buildRuleText("Contains a Capital Letter", hasCapital),
        _buildRuleText("Contains a Number digit", hasDigit),
        _buildRuleText("Contains a Special character", hasSpecial),
        const SizedBox(height: 16),
        TextField(
            controller: _confirmPassController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder())
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: _finalizePassword, child: const Text("Complete Registration"))
      ],
    );
  }
}