import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'firebase_options.dart';
// import 'services/notification_service.dart';
import 'services/analytics_service.dart';
import 'main_navigation.dart';
import 'services/theme_service.dart';
import 'services/connectivity_service.dart';
import 'theme.dart';
import 'components/auth_wrapper.dart';
import 'components/connectivity_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ConnectivityService.initialize();
  await dotenv.load();
  // Allow self-signed/invalid certs for this specific host (temporary until proper cert is installed)
  HttpOverrides.global = _DevHttpOverrides();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // await NotificationService.instance.initialize();
  await ThemeService.instance.load();

  // Initialize Firebase Analytics
  FirebaseAnalytics analytics = FirebaseAnalytics.instance;
  await analytics.setAnalyticsCollectionEnabled(true);
  AnalyticsService.instance.initialize(analytics);

  runApp(MyApp(analytics: analytics));
}

class MyApp extends StatelessWidget {
  final FirebaseAnalytics analytics;

  const MyApp({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'HomeSol',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeService.instance.themeMode,
          builder: (context, child) {
            return ConnectivityWrapper(child: child!);
          },
          home: const AuthWrapper(child: MainNavigation()),
          navigatorObservers: [FirebaseAnalyticsObserver(analytics: analytics)],
        );
      },
    );
  }
}

class _DevHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          return host == '10.0.2.2';
        };
    return client;
  }
}
