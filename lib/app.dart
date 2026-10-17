import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/emergency_repository.dart';
import 'data/repositories/hospital_repository.dart';
import 'data/repositories/user_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/hospital_provider.dart';
import 'screens/splash_screen.dart';

class CareFindApp extends StatelessWidget {
  const CareFindApp({super.key});

  @override
  Widget build(BuildContext context) {
    final userRepository = UserRepository();
    final hospitalRepository = HospitalRepository();
    final emergencyRepository = EmergencyRepository();

    return MultiProvider(
      providers: [
        Provider<UserRepository>.value(value: userRepository),
        Provider<EmergencyRepository>.value(value: emergencyRepository),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(userRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => HospitalProvider(hospitalRepository, userRepository),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
