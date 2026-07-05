import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:Homesol/models/error_log.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/error_log_database.dart';
import 'package:Homesol/utils/app_observer.dart';
import 'package:Homesol/components/crash_report_dialog.dart';
import 'package:Homesol/main.dart';

class ErrorLogger {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static DateTime? _lastDialogTime;

  static Future<void> logError({
    required String logLevel,
    required String module,
    required String action,
    required String message,
    String stackTrace = '',
    bool showDialog = true,
  }) async {
    try {
      final userData = await AuthService.getUserData();
      final user = userData?['email'] ?? 'unknown';
      
      final currentScreen = AppObserver.currentScreenName ?? 'Unknown Screen';
      final enrichedModule = '[$currentScreen] $module';

      String deviceInfoStr = '';
      try {
        if (Platform.isAndroid) {
          final androidInfo = await _deviceInfo.androidInfo;
          deviceInfoStr = 'Android ${androidInfo.version.release}, ${androidInfo.model}, ${androidInfo.manufacturer}';
        } else if (Platform.isIOS) {
          final iosInfo = await _deviceInfo.iosInfo;
          deviceInfoStr = 'iOS ${iosInfo.systemVersion}, ${iosInfo.model}, ${iosInfo.name}';
        }
      } catch (e) {
        deviceInfoStr = 'Error getting device info: $e';
      }

      final errorLog = ErrorLog(
        user: user,
        logLevel: logLevel,
        module: enrichedModule,
        action: action,
        message: message,
        deviceInfo: deviceInfoStr,
        stackTrace: stackTrace,
        timestamp: DateTime.now(),
      );

      final insertedId = await ErrorLogDatabase.insertErrorLog(errorLog);
      
      final logWithId = ErrorLog(
        id: insertedId,
        user: errorLog.user,
        logLevel: errorLog.logLevel,
        module: errorLog.module,
        action: errorLog.action,
        message: errorLog.message,
        deviceInfo: errorLog.deviceInfo,
        stackTrace: errorLog.stackTrace,
        timestamp: errorLog.timestamp,
      );

      // Show Crash Report Dialog with debounce
      if (showDialog) {
        final now = DateTime.now();
        if (_lastDialogTime == null || now.difference(_lastDialogTime!).inSeconds > 5) {
          _lastDialogTime = now;
          
          final context = MyApp.navigatorKey.currentContext;
          if (context != null) {
            // Use a small delay to ensure the log is saved and UI is ready
            Future.delayed(const Duration(milliseconds: 500), () {
              if (MyApp.navigatorKey.currentContext != null) {
                CrashReportDialog.show(MyApp.navigatorKey.currentContext!, logWithId);
              }
            });
          }
        }
      }
    } catch (e) {
      // If logging fails, we don't want to crash the app
      print('Failed to log error to local DB: $e');
    }
  }
}
