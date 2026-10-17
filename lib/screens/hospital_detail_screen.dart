import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/hospital.dart';
import '../providers/auth_provider.dart';
import '../providers/hospital_provider.dart';
import 'login_screen.dart';

class HospitalDetailScreen extends StatefulWidget {
  const HospitalDetailScreen({super.key, required this.hospitalId});

  final String hospitalId;

  @override
  State<HospitalDetailScreen> createState() => _HospitalDetailScreenState();
}

class _HospitalDetailScreenState extends State<HospitalDetailScreen> {
  Hospital? _hospital;
  bool _loading = true;
  int _userRating = 5;
  final _reviewController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final provider = context.read<HospitalProvider>();
    final hospital = await provider.getHospitalDetails(widget.hospitalId);
    await provider.loadReviews(widget.hospitalId);
    if (mounted) {
      setState(() {
        _hospital = hospital;
        _loading = false;
      });
      if (hospital != null && !hospital.hasPhone) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone number listed online for this facility'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMaps(Hospital h) async {
    final uri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${h.latitude}&mlon=${h.longitude}'
      '#map=17/${h.latitude}/${h.longitude}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _submitReview() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    await context.read<HospitalProvider>().submitReview(
          userId: auth.user!.id,
          hospitalId: widget.hospitalId,
          rating: _userRating,
          text: _reviewController.text,
        );
    _reviewController.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading facility details…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Fetching phone number from online listing if available',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final h = _hospital;
    if (h == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Hospital not found')),
      );
    }

    final auth = context.watch<AuthProvider>();
    final provider = context.watch<HospitalProvider>();
    final isFav = provider.isFavorite(h.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(h.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (auth.isLoggedIn)
            IconButton(
              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
              onPressed: () => provider.toggleFavorite(auth.user!.id, h.id),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (h.verified)
            const Chip(
              avatar: Icon(Icons.verified, size: 18),
              label: Text('Verified listing'),
            ),
          const SizedBox(height: 8),
          _InfoRow(Icons.place, h.address),
          if (h.phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(Icons.phone, h.phone),
          ],
          if (h.distanceKm != null) ...[
            const SizedBox(height: 8),
            _InfoRow(Icons.directions, '${h.distanceKm} km away'),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, color: Colors.amber),
              const SizedBox(width: 4),
              Text('${h.rating.toStringAsFixed(1)} (${h.totalReviews} Google reviews)'),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (h.emergencyAvailable) _tag('Emergency', Colors.red),
              if (h.hasIcu) _tag('ICU', Colors.blue),
              if (h.hasAmbulance) _tag('Ambulance', Colors.orange),
              if (h.hasBloodBank) _tag('Blood Bank', Colors.purple),
            ],
          ),
          if (h.specialities.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Specialities', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: h.specialities.map((s) => Chip(label: Text(s))).toList(),
            ),
          ],
          if (h.services.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Services', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: h.services.map((s) => Chip(label: Text(s))).toList(),
            ),
          ],
          if (h.openingHours.isNotEmpty) ...[
            const SizedBox(height: 16),
            _InfoRow(Icons.schedule, h.openingHours),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: h.phone.isNotEmpty ? () => _call(h.phone) : null,
                  icon: const Icon(Icons.call),
                  label: const Text('Call'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    provider.showDirectionsOnMap(h);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: () => _openMaps(h),
                tooltip: 'Open in browser map',
                icon: const Icon(Icons.open_in_new),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Reviews', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...provider.reviews.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(r.userName),
                subtitle: Text(r.reviewText),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${r.rating}'),
                    const Icon(Icons.star, size: 16, color: Colors.amber),
                  ],
                ),
              )),
          if (auth.isLoggedIn) ...[
            const SizedBox(height: 16),
            Text('Write a review', style: Theme.of(context).textTheme.titleMedium),
            Row(
              children: List.generate(5, (i) {
                return IconButton(
                  icon: Icon(
                    i < _userRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () => setState(() => _userRating = i + 1),
                );
              }),
            ),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Share your experience...'),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitReview,
              child: const Text('Submit Review'),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'Place ID: ${h.googlePlaceId}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Cached: ${h.cachedAt != null ? DateFormat.yMMMd().format(h.cachedAt!) : '—'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
