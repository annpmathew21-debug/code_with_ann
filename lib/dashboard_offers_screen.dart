import 'package:flutter/material.dart';
import 'home_screen.dart';

class DashboardOffersScreen extends StatelessWidget {
  final int score;
  final String userName;
  final String userAvatar;

  const DashboardOffersScreen({
    super.key,
    required this.score,
    required this.userName,
    required this.userAvatar
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text("Hey $userName $userAvatar", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Colors.teal, Colors.tealAccent]),
                    borderRadius: BorderRadius.circular(20)
                ),
                child: Column(
                  children: [
                    const Text("YOUR WELLNESS INDEX", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("$score / 160", style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(
                        chosenCourse: "General Wellness",
                        passedName: userName,
                        passedAvatar: userAvatar,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Submit & Enter Dashboard", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}