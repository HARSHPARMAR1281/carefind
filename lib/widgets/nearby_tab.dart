import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            if (!provider.locationLive && provider.usingLastKnownLocation)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Using last known location — turn on GPS for live results',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.orange.shade800,
                      ),
                  textAlign: TextAlign.center,
                ),
              )
            else if (!provider.locationLive && provider.position == null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  'Location off — enable location to see nearby hospitals',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade700,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (provider.loadingNearby && provider.nearby.isNotEmpty)
              const LinearProgressIndicator(minHeight: 2),
            if (!provider.loadingNearby && provider.nearbyPool.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(
                  '${provider.nearby.length} hospitals & facilities'
                      '${provider.nearbyFilters.hasActiveFilters ? ' (filtered)' : ''}'
                      ' — major hospitals ranked first',
                  style: Theme.of(context).textTheme.bodySmall,
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
