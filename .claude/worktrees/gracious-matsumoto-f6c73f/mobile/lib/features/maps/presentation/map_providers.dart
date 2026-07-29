import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/location_service.dart';
import '../../home/data/models/observation_summary.dart';
import '../data/map_clusterer.dart';
import '../data/map_remote_datasource.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MAP PROVIDERS
/// ─────────────────────────────────────────────────────────────────────────────

final mapDataSourceProvider = Provider<IMapRemoteDataSource>(
  (ref) => MapRemoteDataSource(dio: ref.read(dioProvider)),
  name: 'mapDataSource',
);

/// Optional state filter for the map (null = whole of India).
final mapStateFilterProvider = StateProvider<int?>(
  (ref) => null,
  name: 'mapStateFilter',
);

/// Privacy filter for the map ('public', 'private', or 'all').
final mapPrivacyFilterProvider = StateProvider<String>(
  (ref) => 'public',
  name: 'mapPrivacyFilter',
);

/// True only for a finite, in-range lat/lng pair. Guards against bad backend
/// data — an out-of-range value would make `LatLng(...)` throw and blank the
/// whole map screen.
bool isPlottableCoord(double? lat, double? lng) =>
    lat != null &&
    lng != null &&
    lat.isFinite &&
    lng.isFinite &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180;

/// Sightings that have coordinates, filtered by state and privacy, for plotting.
final mapSightingsProvider =
    FutureProvider.autoDispose<List<ObservationSummary>>((ref) async {
  final stateId = ref.watch(mapStateFilterProvider);
  final privacy = ref.watch(mapPrivacyFilterProvider);
  final all = await ref
      .read(mapDataSourceProvider)
      .fetchSightings(stateId: stateId, privacy: privacy);
  // Only sightings with valid, in-range coordinates can be plotted.
  return all
      .where((o) => isPlottableCoord(o.latitude, o.longitude))
      .toList();
}, name: 'mapSightings');

/// Cluster points derived from the loaded sightings.
final mapClusterPointsProvider =
    Provider.autoDispose<List<ClusterPoint>>((ref) {
  final sightings = ref.watch(mapSightingsProvider).valueOrNull ?? const [];
  return [
    for (final o in sightings)
      ClusterPoint(id: o.id, lat: o.latitude!, lng: o.longitude!),
  ];
}, name: 'mapClusterPoints');

/// The user's current GPS coordinates (null if unavailable / denied).
final userLocationProvider =
    FutureProvider.autoDispose<GeoCoords?>((ref) {
  return ref.read(locationServiceProvider).currentCoords();
}, name: 'userLocation');
