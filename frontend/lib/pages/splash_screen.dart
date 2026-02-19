import 'package:Homesol/pages/loader_video_screen.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../services/apis/user/user_service.dart';
import 'auth/login_page.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize Firebase (best-effort) and register FCM token if logged in
    _initPush();

    // Immediately navigate to loader video which will fetch and route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const LoaderVideoScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    });
  }

  Future<void> _initPush() async {
    try {
      await Firebase.initializeApp();
      final settings = await FirebaseMessaging.instance.requestPermission();
      // Proceed if permission is authorized or provisional
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      final user = await AuthService.getUserData();
      final brokerId = user?['broker_id']?.toString();
        if (token != null && brokerId != null && brokerId.isNotEmpty) {
        await UserService.registerDeviceToken(
          brokerId: brokerId,
          token: token,
          platform: 'android',
        );
      }

      // Handle token refresh
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        final u = await AuthService.getUserData();
        final bId = u?['broker_id']?.toString();
        if (bId != null && bId.isNotEmpty) {
          await UserService.registerDeviceToken(
            brokerId: bId,
            token: newToken,
            platform: 'android',
          );
        }
      });
    } catch (_) {
      // ignore failures
    }
  }

  // old _checkAuthAndNavigate removed; routing handled by LoaderVideoScreen

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF15181D),
      body: Center(
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFddbe6c).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              'assets/logo/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
