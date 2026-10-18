import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils/permission_utils.dart';
import '../data/models/hospital.dart';
import '../data/models/nearby_filters.dart';
import '../providers/auth_provider.dart';
import '../providers/hospital_provider.dart';
import '../screens/hospital_detail_screen.dart';
import 'hospital_card.dart';

class NearbyTab extends StatelessWidget {
  const NearbyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const TabBar(
              tabs: [
                Tab(text: 'Nearby', icon: Icon(Icons.near_me)),
                Tab(text: 'Search India', icon: Icon(Icons.travel_explore)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const _NearbyListPanel(),
                const _GlobalSearchPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyListPanel extends StatefulWidget {
  const _NearbyListPanel();

  @override
  State<_NearbyListPanel> createState() => _NearbyListPanelState();
}

class _NearbyListPanelState extends State<_NearbyListPanel> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HospitalProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    decoration: InputDecoration(
                      hintText: 'Search nearby e.g. Manipal, Apollo...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                provider.clearNameSearch();
                              },
                            )
                          : null,
                    ),
                    onChanged: provider.updateSearchPrefix,
                    onSubmitted: provider.applyNameSearch,
                  ),
                  if (provider.nameSuggestions.isNotEmpty &&
                      _searchFocus.hasFocus)
                    Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(8),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.nameSuggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final h = provider.nameSuggestions[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(h.categoryIcon, size: 20),
                            title: Text(h.name),
                            subtitle: Text(
                              h.categoryLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            onTap: () {
                              _searchController.text = h.name;
                              provider.applyNameSearch(h.name);
                              _searchFocus.unfocus();
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            _FilterBar(provider: provider),
            _LocationStatus(provider: provider),
            if (provider.loadingNearby && provider.nearby.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            if (provider.nearbyPool.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${provider.nearby.length} facilities'
                        '${provider.nearbyFilters.hasActiveFilters ? ' (filtered)' : ''}'
                        ' within ${provider.nearbyRadiusKm.round()} km',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: true, label: Text('Nearest')),
                        ButtonSegment(value: false, label: Text('Top ranked')),
                      ],
                      selected: {provider.sortNearestFirst},
                      onSelectionChanged: (s) =>
                          provider.setSortNearestFirst(s.first),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: provider.loadingNearby && provider.nearby.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.error != null && provider.nearby.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(provider.error!),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: provider.refreshNearby,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : provider.nearby.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      provider.nearbyFilters.hasActiveFilters
                                          ? Icons.filter_alt_off
                                          : Icons.location_off,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      provider.nearbyFilters.hasActiveFilters
                                          ? 'No facilities match your filters'
                                          : 'No hospitals found nearby',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: provider.refreshNearby,
                              child: ListView.builder(
                                itemCount: provider.nearby.length,
                                itemBuilder: (context, index) {
                                  return _HospitalListTile(
                                    hospital: provider.nearby[index],
                                  );
                                },
                              ),
                            ),
            ),
          ],
        );
      },
    );
  }
}

/// One line that always says which location the list is based on, with a
/// button to fix it when location is not available.
class _LocationStatus extends StatelessWidget {
  const _LocationStatus({required this.provider});

  final HospitalProvider provider;

  @override
  Widget build(BuildContext context) {
    final pos = provider.position;
    final coords = pos == null
        ? ''
        : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
    final access = provider.locationAccess;

    IconData icon = Icons.location_off;
    Color color = Colors.orange.shade800;
    String text;
    String? actionLabel;
    VoidCallback? onAction;

    if (provider.locationLive) {
      icon = Icons.my_location;
      color = Colors.green.shade800;
      text = 'Using your live location ($coords)';
    } else if (access == LocationAccess.denied) {
      color = Colors.red.shade700;
      text = 'Location permission is needed to find hospitals near you.';
      actionLabel = 'Allow';
      onAction = provider.requestLocationAndRefresh;
    } else if (access == LocationAccess.deniedForever) {
      color = Colors.red.shade700;
      text = 'Location permission is blocked for CareFind.';
      actionLabel = 'Open settings';
      onAction = provider.requestLocationAndRefresh;
    } else if (access == LocationAccess.serviceOff) {
      color = Colors.red.shade700;
      text = 'Location (GPS) is turned off on this phone.';
      actionLabel = 'Turn on';
      onAction = provider.requestLocationAndRefresh;
    } else if (provider.usingLastKnownLocation) {
      text = 'No fresh GPS fix - showing results near your last known '
          'location ($coords).';
      actionLabel = 'Retry';
      onAction = provider.refreshNearby;
    } else if (provider.loadingNearby) {
      return const SizedBox.shrink();
    } else {
      text = 'Waiting for your location...';
      actionLabel = 'Retry';
      onAction = provider.refreshNearby;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.provider});

  final HospitalProvider provider;

  @override
  Widget build(BuildContext context) {
    final filters = provider.nearbyFilters;
    final selectedCategory = filters.category ?? 'all';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          ...NearbyFilters.categoryFilters.map((entry) {
            final (id, label) = entry;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(label),
                selected: selectedCategory == id,
                onSelected: (_) => provider.setCategoryFilter(id),
              ),
            );
          }),
          FilterChip(
            label: const Text('Emergency'),
            selected: filters.emergencyOnly,
            onSelected: provider.setEmergencyFilter,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: DropdownButton<String?>(
              hint: const Text('Speciality'),
              value: filters.speciality,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All specialities'),
                ),
                ...NearbyFilters.commonSpecialities.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s)),
                ),
              ],
              onChanged: provider.setSpecialityFilter,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalSearchPanel extends StatefulWidget {
  const _GlobalSearchPanel();

  @override
  State<_GlobalSearchPanel> createState() => _GlobalSearchPanelState();
}

class _GlobalSearchPanelState extends State<_GlobalSearchPanel> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HospitalProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'e.g. Fortis Jaipur, AIIMS Delhi, Apollo Chennai',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            provider.searchEverywhere('');
                          },
                        )
                      : null,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: provider.searchEverywhere,
              ),
            ),
            Expanded(
              child: provider.loadingGlobalSearch
                  ? const Center(child: CircularProgressIndicator())
                  : provider.globalSearchQuery.isEmpty
                      ? _NearbyFallbackList(
                          hospitals: provider.prominentNearby,
                          subtitle:
                              'Major hospitals near you — search above for any city in India',
                        )
                      : provider.globalSearchResults.isEmpty
                          ? Center(
                              child: Text(
                                'No results for "${provider.globalSearchQuery}"',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: provider.globalSearchResults.length,
                              itemBuilder: (context, index) {
                                final hospital =
                                    provider.globalSearchResults[index];
                                return _HospitalListTile(
                                  hospital: hospital,
                                  trailing: IconButton(
                                    tooltip: 'Show on map',
                                    icon: const Icon(Icons.map_outlined),
                                    onPressed: () =>
                                        provider.focusSearchOnMap(hospital),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}

class _NearbyFallbackList extends StatelessWidget {
  const _NearbyFallbackList({
    required this.hospitals,
    required this.subtitle,
  });

  final List<Hospital> hospitals;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    if (hospitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: hospitals.length,
            itemBuilder: (context, index) {
              return _HospitalListTile(hospital: hospitals[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _HospitalListTile extends StatelessWidget {
  const _HospitalListTile({
    required this.hospital,
    this.trailing,
  });

  final Hospital hospital;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<HospitalProvider>();
    final auth = context.read<AuthProvider>();

    return Stack(
      children: [
        HospitalCard(
          hospital: hospital,
          isFavorite: provider.isFavorite(hospital.id),
          onFavoriteToggle: auth.isLoggedIn
              ? () => provider.toggleFavorite(auth.user!.id, hospital.id)
              : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HospitalDetailScreen(hospitalId: hospital.id),
            ),
          ),
        ),
        if (trailing != null)
          Positioned(
            right: 48,
            top: 8,
            child: trailing!,
          ),
      ],
    );
  }
}
