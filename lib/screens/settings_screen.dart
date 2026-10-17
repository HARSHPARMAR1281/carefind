import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('About CareFind'),
            subtitle: Text(
              'Hospital finder with dual-database architecture:\n'
              '• Hospital DB — cached & enriched listings\n'
              '• User DB — accounts, favorites, reviews',
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Privacy & data'),
            subtitle: const Text(
              'Location is used for nearby hospital discovery. '
              'Your last known location is saved when GPS is active. '
              'Emergency alerts use your phone dialer and SMS app. '
              'User data is stored locally in a separate database.',
            ),
            leading: const Icon(Icons.privacy_tip_outlined),
          ),
          if (context.watch<AuthProvider>().isLoggedIn)
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(context.read<AuthProvider>().user!.email),
            ),
        ],
      ),
    );
  }
}
