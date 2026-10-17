import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/hospital_provider.dart';
import '../widgets/emergency_trigger.dart';
import '../widgets/favorites_tab.dart';
import '../widgets/map_tab.dart';
import '../widgets/nearby_tab.dart';
import '../widgets/profile_tab.dart';
import 'emergency_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _index = 0;
  HospitalProvider? _hospitalProvider;

  static const _tabs = [
    ('Nearby', Icons.list),
    ('Map', Icons.map),
    ('Favorites', Icons.favorite),
    ('Profile', Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _hospitalProvider = context.read<HospitalProvider>();
      _hospitalProvider!.addListener(_onHospitalProviderChanged);
      if (auth.isLoggedIn) {
        _hospitalProvider!.loadFavorites(auth.user!.id);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hospitalProvider?.removeListener(_onHospitalProviderChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<HospitalProvider>().refreshNearby();
    }
  }

  void _onHospitalProviderChanged() {
    final provider = _hospitalProvider;
    if (provider == null) return;
    if (provider.openMapTabRequest) {
      provider.clearMapTabRequest();
      if (mounted) setState(() => _index = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodies = [
      const NearbyTab(),
      const MapTab(),
      const FavoritesTab(),
      const ProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('CareFind'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emergency),
            tooltip: 'Emergency settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencyScreen()),
            ),
          ),
        ],
      ),
      body: bodies[_index],
      floatingActionButton: const EmergencyTriggerButton(compact: true),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _tabs
            .map((t) => NavigationDestination(icon: Icon(t.$2), label: t.$1))
            .toList(),
      ),
    );
  }
}
