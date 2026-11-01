import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'registration_screen.dart';
import 'home_screen.dart';
import 'database_helper.dart';

// Initialize the plugin globally
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Timezone data for scheduling
  tz.initializeTimeZones();

  // Configure Notification settings for Android
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings =
  InitializationSettings(android: initializationSettingsAndroid);

  // Initialize the plugin
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const WellnessApp());
}

class WellnessApp extends StatelessWidget {
  const WellnessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wellness Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identityController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identityController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String input) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(input);
  }

  bool _isValidPhone(String input) {
    return input.length == 10 && int.tryParse(input) != null;
  }

  void _handleLogin() async {
    String identity = _identityController.text.trim();
    String password = _passwordController.text.trim();

    if (identity.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Email/Phone and Password')));
      return;
    }

    if (!_isValidEmail(identity) && !_isValidPhone(identity)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid Email or 10-digit Phone'), backgroundColor: Colors.redAccent));
      return;
    }

    final userDetails = await DatabaseHelper.findUser(identity);

    if (userDetails == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Row(children: [Icon(Icons.person_search_rounded, color: Colors.orangeAccent), SizedBox(width: 10), Text("No Specific Data", style: TextStyle(fontWeight: FontWeight.bold))]),
          content: const Text("No specific user data found. Click OK to set up a new account on the Registration Screen!"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen()));
              },
              child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
            )
          ],
        ),
      );
      return;
    }

    if (userDetails['password'] != password) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect password! Please try again.'), backgroundColor: Colors.redAccent));
      return;
    }

    // Navigating to HomeScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          chosenCourse: "General Wellness",
          passedName: userDetails['name'] ?? "User",
          passedAvatar: userDetails['avatar'] ?? "",
          passedEmail: identity,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.spa_rounded, size: 80, color: Colors.teal),
                  const SizedBox(height: 16),
                  const Text("Wellness Companion", textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF212529))),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _identityController,
                    decoration: InputDecoration(labelText: 'Email or Mobile Number', prefixIcon: const Icon(Icons.person_outline_rounded), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                        labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: const Text('Secure Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen())),
                    child: const Text("Don't have an account? Register Here", style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}