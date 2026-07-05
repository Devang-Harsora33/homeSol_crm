import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../pages/auth/login_page.dart';
import '../services/tracking_service.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;
  final bool requireAuth;

  const AuthWrapper({super.key, required this.child, this.requireAuth = true});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    // Request tracking permission for iOS
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TrackingService.requestTrackingPermission();
    });
  }

  Future<void> _checkAuthStatus() async {
    print(
      'AuthWrapper: Checking auth status, requireAuth: ${widget.requireAuth}',
    );
    if (!widget.requireAuth) {
      print('AuthWrapper: Auth not required, showing child');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticated = true;
        });
      }
      return;
    }

    try {
      print('AuthWrapper: Calling AuthService.isLoggedIn()');
      final isLoggedIn = await AuthService.isLoggedIn();
      print('AuthWrapper: AuthService.isLoggedIn() returned: $isLoggedIn');
      if (mounted) {
        setState(() {
          _isAuthenticated = isLoggedIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('AuthWrapper: Error checking auth status: $e');
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
      'AuthWrapper: Building, _isLoading: $_isLoading, _isAuthenticated: $_isAuthenticated, requireAuth: ${widget.requireAuth}',
    );
    if (_isLoading) {
      print('AuthWrapper: Showing loading screen');
      return Scaffold(
        backgroundColor: const Color(0xFF15181D),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFddbe6c).withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: 2,
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
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFddbe6c)),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isAuthenticated && widget.requireAuth) {
      print('AuthWrapper: Showing login page');
      return const LoginPage();
    }

    print('AuthWrapper: Showing main app');
    return widget.child;
  }
}
