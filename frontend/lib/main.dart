import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:upgrader/upgrader.dart';
import 'package:Homesol/utils/error_logger.dart';
import 'package:Homesol/utils/app_observer.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/notification_manager.dart';
import 'services/analytics_service.dart';
import 'main_navigation.dart';
import 'services/theme_service.dart';
import 'services/connectivity_service.dart';
import 'theme.dart';
import 'components/auth_wrapper.dart';
import 'components/connectivity_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup Global Error Handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLogger.logError(
      logLevel: 'ERROR',
      module: 'FlutterError',
      action: 'GlobalHandler',
      message: details.exceptionAsString(),
      stackTrace: details.stack.toString(),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLogger.logError(
      logLevel: 'ERROR',
      module: 'PlatformDispatcher',
      action: 'GlobalHandler',
      message: error.toString(),
      stackTrace: stack.toString(),
    );
    return true;
  };

  // Allow self-signed/invalid certs for this specific host (temporary until proper cert is installed)
  HttpOverrides.global = _DevHttpOverrides();

  // 1. Load connectivity
  ConnectivityService.initialize();
  
  // 2. Load environment variables
  try {
    await dotenv.load();
    debugPrint('Main: dotenv loaded');
  } catch (e) {
    debugPrint('Main: Error loading .env: $e');
  }
  
  // 3. Initialize Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('Main: Firebase initialized');
  } catch (e) {
    debugPrint('Main: Firebase initialization error: $e');
  }
  
  // 4. Initialize Notifications
  try {
    await NotificationService.instance.initialize();
    await NotificationManager.instance.initialize();
    debugPrint('Main: Notifications initialized');
  } catch (e) {
    debugPrint('Main: Notification initialization error: $e');
  }
  
  // 5. Initialize Theme
  try {
    await ThemeService.instance.load();
    debugPrint('Main: Theme loaded');
  } catch (e) {
    debugPrint('Main: Theme load error: $e');
  }

  // 6. Initialize Firebase Analytics
  FirebaseAnalytics? analytics;
  try {
    analytics = FirebaseAnalytics.instance;
    await analytics.setAnalyticsCollectionEnabled(true);
    AnalyticsService.instance.initialize(analytics);
    debugPrint('Main: Analytics initialized');
  } catch (e) {
    debugPrint('Main: Analytics initialization error: $e');
  }
  
  runApp(MyApp(analytics: analytics));
}

class MyApp extends StatelessWidget {
  final FirebaseAnalytics? analytics;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key, this.analytics});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'HomeSol',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeService.instance.themeMode,
          builder: (context, child) {
            return ConnectivityWrapper(child: child!);
          },
          home: UpgradeAlert(
            child: const AuthWrapper(child: MainNavigation()),
          ),
          navigatorObservers: [
            AppObserver(),
            if (analytics != null) FirebaseAnalyticsObserver(analytics: analytics!),
          ],
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
