import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_storage_service.dart';
import 'features/soil_analysis/screens/home_screen.dart';
import 'features/soil_analysis/services/agricultural_monitoring_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgBottom,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // runApp fires immediately after binding initialization
  runApp(const FarmSenseApp());
}

class FarmSenseApp extends StatefulWidget {
  const FarmSenseApp({super.key});

  @override
  State<FarmSenseApp> createState() => _FarmSenseAppState();
}

class _FarmSenseAppState extends State<FarmSenseApp> {
  late final Future<bool> _authFuture;

  @override
  void initState() {
    super.initState();
    // Lock orientations once widget tree is mounted to prevent 0x0 viewport stalls
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    _authFuture = _initializeStartupServices();
  }

  Future<bool> _initializeStartupServices() async {
    // Fire saved farm location & legacy storage migrations in the background (non-blocking)
    unawaited(AgriculturalMonitoringService.instance.initSavedLocations());

    // Only await the lightweight auth verification (~1ms) for instant time-to-first-screen
    return AuthStorageService.instance.isLoggedIn();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: FutureBuilder<bool>(
        future: _authFuture,
        builder: (context, snapshot) {
          // While resolving SharedPreferences, render the app's ambient
          // gradient background for a seamless, instant first frame matching
          // the app's visual identity (no harsh dark screen or flash).
          if (!snapshot.hasData) {
            return const Scaffold(
              backgroundColor: AppColors.bgTop,
              body: SizedBox.expand(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.bgTop,
                        AppColors.bgMid,
                        AppColors.bgBottom,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            );
          }
          return snapshot.data == true
              ? const HomeScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
