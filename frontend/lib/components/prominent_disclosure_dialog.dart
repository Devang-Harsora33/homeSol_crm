import 'package:flutter/material.dart';

class ProminentDisclosureScreen extends StatelessWidget {
  const ProminentDisclosureScreen({super.key});

  // Updated to push a full-screen route instead of a popup dialog
  static Future<bool> show(BuildContext context) async {
    return await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const ProminentDisclosureScreen(),
        fullscreenDialog: true, // Gives it a nice slide-up modal feel
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Forces the pure white background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              
              // 1. Visual Icon: Grabs attention and sets the context
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFFddbe6c).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 80,
                  color: Color(0xFFddbe6c),
                ),
              ),
              const SizedBox(height: 40),
              
              // 2. Clear Headline
              const Text(
                "Location Access Required",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // 3. The Required Disclosure Text (Well spaced)
              const Text(
                "HomeSol Nexus collects location data to enable automatic attendance logging and project range detection while you are using the app.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
              
              // 4. Primary Action Button (Full Width)
              SizedBox(
                width: double.infinity,
                height: 56, // Tall, easy-to-tap button
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFddbe6c),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 5. Secondary Action Button (Subtle)
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  foregroundColor: Colors.grey.shade500,
                ),
                child: const Text(
                  "Decline",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}