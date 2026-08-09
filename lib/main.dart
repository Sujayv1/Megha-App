import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/services/auth_storage_service.dart';
import 'features/soil_analysis/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait for a consistent farmer dashboard UX
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bgBottom,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final isLoggedIn = await AuthStorageService.instance.isLoggedIn();

  runApp(FarmSenseApp(isLoggedIn: isLoggedIn));
}

class FarmSenseApp extends StatelessWidget {
  final bool isLoggedIn;
  const FarmSenseApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmSense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
