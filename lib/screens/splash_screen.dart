import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/app_config.dart';
import '../core/utils/location_utils.dart';
import '../core/utils/network_utils.dart';
import '../core/utils/permission_utils.dart';
import '../data/repositories/emergency_repository.dart';
import '../providers/auth_provider.dart';
import '../providers/hospital_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _ensureLocationEnabled() async {
    // Shows the system "Allow location?" dialog the first time.
    final access = await PermissionUtils.requestLocationAccess();
    if (access == LocationAccess.granted || !mounted) return;

    final String message;
    final String action;
    if (access == LocationAccess.serviceOff) {
      message = 'Location (GPS) is turned off. Turn it on to see hospitals '
          'near you.';
      action = 'Turn on location';
    } else if (access == LocationAccess.deniedForever) {
      message = 'Location permission is blocked for CareFind. Allow it in '
          'app settings to see hospitals near you.';
      action = 'Open settings';
    } else {
      message = 'CareFind needs your location to show nearby hospitals.';
      action = 'Allow location';
    }

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_off, size: 40),
        title: const Text('Location required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continue anyway'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Done after the dialog has closed, and awaited, so the app does not start
    // its own location request while the system permission dialog is open.
    if (access == LocationAccess.serviceOff) {
      await LocationUtils.openLocationSettings();
    } else if (access == LocationAccess.deniedForever) {
      await LocationUtils.openAppSettings();
    } else {
      await PermissionUtils.requestLocationAccess();
    }
  }

  Future<void> _bootstrap() async {
    final online = await NetworkUtils.hasConnection();
    if (!online && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No internet — using cached data')),
      );
    }

    await _ensureLocationEnabled();

    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final hospitals = context.read<HospitalProvider>();
    final emergencyRepo = context.read<EmergencyRepository>();

    await auth.initialize();
    await hospitals.initialize();

    if (auth.isLoggedIn) {
      await emergencyRepo.importFromUserAccount(auth.user!.id);
      await hospitals.loadFavorites(auth.user!.id);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => auth.isLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.local_hospital, size: 80, color: Colors.white),
            const SizedBox(height: 24),
            Text(
              AppConfig.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Find trusted hospitals near you',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
