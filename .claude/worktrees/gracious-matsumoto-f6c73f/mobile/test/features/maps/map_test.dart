import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butterfly_india/features/home/data/models/observation_summary.dart';
import 'package:butterfly_india/features/maps/data/map_remote_datasource.dart';
import 'package:butterfly_india/features/maps/presentation/map_providers.dart';

class _FakeMapDataSource implements IMapRemoteDataSource {
  _FakeMapDataSource(this.sightings);
  final List<ObservationSummary> sightings;

  @override
  Future<List<ObservationSummary>> fetchSightings({
    int? stateId,
    String? privacy,
    int perPage = 100,
  }) async =>
      sightings;
}

void main() {
  group('isPlottableCoord', () {
    test('accepts in-range finite coordinates', () {
      expect(isPlottableCoord(22.5, 79.0), isTrue);
      expect(isPlottableCoord(-90, -180), isTrue);
      expect(isPlottableCoord(90, 180), isTrue);
    });

    test('rejects null / out-of-range / non-finite', () {
      expect(isPlottableCoord(null, 79.0), isFalse);
      expect(isPlottableCoord(22.5, null), isFalse);
      expect(isPlottableCoord(200, 79.0), isFalse); // lat too big
      expect(isPlottableCoord(22.5, 999), isFalse); // lng too big
      expect(isPlottableCoord(double.nan, 0), isFalse);
      expect(isPlottableCoord(0, double.infinity), isFalse);
    });
  });

  group('mapSightingsProvider', () {
    test('drops sightings with invalid coordinates so the map never crashes',
        () async {
      final data = <ObservationSummary>[
        const ObservationSummary(id: 'good', latitude: 12.9, longitude: 77.5),
        const ObservationSummary(id: 'bad-range', latitude: 200, longitude: 77.5),
        const ObservationSummary(id: 'missing', latitude: null, longitude: null),
      ];
      final container = ProviderContainer(overrides: [
        mapDataSourceProvider.overrideWithValue(_FakeMapDataSource(data)),
      ]);
      addTearDown(container.dispose);

      final result = await container.read(mapSightingsProvider.future);

      expect(result.map((o) => o.id), ['good']);
    });
  });
}
