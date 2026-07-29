import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../data/geography_models.dart';
import '../data/geography_remote_datasource.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// GEOGRAPHY PROVIDERS
/// States are cached for the session; districts are loaded per selected state.
/// ─────────────────────────────────────────────────────────────────────────────

final geographyDataSourceProvider = Provider<IGeographyRemoteDataSource>(
  (ref) => GeographyRemoteDataSource(dio: ref.read(dioProvider)),
  name: 'geographyDataSource',
);

final statesProvider = FutureProvider<List<IndiaState>>(
  (ref) => ref.read(geographyDataSourceProvider).fetchStates(),
  name: 'states',
);

final districtsProvider =
    FutureProvider.family<List<IndiaDistrict>, int>(
  (ref, stateId) =>
      ref.read(geographyDataSourceProvider).fetchDistricts(stateId),
  name: 'districts',
);
