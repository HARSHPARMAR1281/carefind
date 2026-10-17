import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/hospital_provider.dart';
import '../screens/hospital_detail_screen.dart';
import '../screens/login_screen.dart';
import 'hospital_card.dart';

class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final hospitals = context.watch<HospitalProvider>();

    if (!auth.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Sign in to save favorite hospitals'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    }

    if (hospitals.favorites.isEmpty) {
      return const Center(
        child: Text('No favorites yet. Tap ♥ on a hospital to save it.'),
      );
    }

    return ListView.builder(
      itemCount: hospitals.favorites.length,
      itemBuilder: (context, index) {
        final hospital = hospitals.favorites[index];
        return HospitalCard(
          hospital: hospital,
          isFavorite: true,
          onFavoriteToggle: () => hospitals.toggleFavorite(
            auth.user!.id,
            hospital.id,
          ),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HospitalDetailScreen(hospitalId: hospital.id),
            ),
          ),
        );
      },
    );
  }
}
