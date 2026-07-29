import 'dart:io';
import 'package:dartz/dartz.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../observations/data/datasources/observation_remote_datasource.dart';
import '../../../observations/data/models/observation.dart';
import '../../../species/data/repositories/species_repository.dart';
import '../classifier/butterfly_classifier.dart';
import '../datasources/ai_remote_datasource.dart';
import '../models/ai_result.dart';

/// Combined output of a quick-scan: the created sighting + the AI result.
class AiScanResult {
  const AiScanResult({required this.observation, required this.result});
  final Observation observation;
  final AiResult result;
}

/// Pipeline stage for progress UI.
enum ScanStage { compressing, creating, uploading, analysing, done }

typedef ScanProgress = void Function(ScanStage stage);

/// ─────────────────────────────────────────────────────────────────────────────
/// AI REPOSITORY
/// Quick-scan orchestration: photo → observation → identification.
/// Identification runs ON-DEVICE (TFLite) — no network, no API quota. If the
/// on-device model isn't installed yet, it falls back to the backend endpoint.
/// ─────────────────────────────────────────────────────────────────────────────

abstract class IAiRepository {
  Future<Either<Failure, AiScanResult>> identifyFromImage({
    required File image,
    required int stateId,
    required String privacy,
    ScanProgress? onProgress,
  });

  Future<Either<Failure, AiResult>> getResult(String observationId);
}

class AiRepository implements IAiRepository {
  AiRepository({
    required IObservationRemoteDataSource observationRemote,
    required IAiRemoteDataSource aiRemote,
    required IButterflyClassifier classifier,
    required ISpeciesRepository speciesRepository,
    required IConnectivityService connectivity,
  })  : _obs = observationRemote,
        _ai = aiRemote,
        _classifier = classifier,
        _species = speciesRepository,
        _connectivity = connectivity;

  final IObservationRemoteDataSource _obs;
  final IAiRemoteDataSource _ai;
  final IButterflyClassifier _classifier;
  final ISpeciesRepository _species;
  final IConnectivityService _connectivity;

  @override
  Future<Either<Failure, AiScanResult>> identifyFromImage({
    required File image,
    required int stateId,
    required String privacy,
    ScanProgress? onProgress,
  }) async {
    if (!_connectivity.isOnline) {
      return const Left(NetworkFailure(
        message: 'Saving a sighting needs an internet connection.',
      ));
    }

    try {
      onProgress?.call(ScanStage.compressing);
      final compressed = await ImageHelper.compress(image);

      onProgress?.call(ScanStage.creating);
      final observation = await _obs.create({
        'state_id': stateId,
        'privacy': privacy,
      });

      onProgress?.call(ScanStage.uploading);
      await _obs.uploadImage(observation.id, compressed);

      onProgress?.call(ScanStage.analysing);
      final result = await _identify(observation.id, compressed);

      onProgress?.call(ScanStage.done);
      return Right(AiScanResult(observation: observation, result: result));
    } on AppException catch (e) {
      return Left(e.toFailure());
    } catch (e) {
      return Left(ExceptionMapper.fromObject(e).toFailure());
    }
  }

  /// Below this top-1 probability we treat the photo as "not confidently a
  /// known butterfly" and show the friendly retry view instead of a shaky guess.
  static const double _minTopConfidence = 0.25;

  /// Identification always runs via the backend API to fetch the rich Gemini JSON schema.
  Future<AiResult> _identify(String observationId, File image) async {
    // We intentionally bypass the local TFLite model here to ensure we hit
    // the backend Gemini API and receive the rich JSON response.
    return _ai.triggerIdentify(observationId);
  }

  /// "BLUE MORPHO" → "Blue Morpho" for display + nicer species-search matching.
  String _prettifyLabel(String label) => label
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// Best-effort: map a predicted label to a backend species for the
  /// "View species" link + thumbnail. Never throws.
  Future<_ResolvedSpecies?> _resolveSpecies(String label) async {
    try {
      final result = await _species.search(label);
      return result.fold((_) => null, (list) {
        if (list.isEmpty) return null;
        final s = list.first;
        return _ResolvedSpecies(
          id: s.id,
          commonName: s.commonName,
          scientificName: s.scientificName,
          primaryImageUrl: s.primaryImageUrl,
          rarity: s.rarity,
        );
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Either<Failure, AiResult>> getResult(String observationId) async {
    try {
      return Right(await _ai.getResult(observationId));
    } on AppException catch (e) {
      return Left(e.toFailure());
    } catch (e) {
      return Left(ExceptionMapper.fromObject(e).toFailure());
    }
  }
}

class _ResolvedSpecies {
  const _ResolvedSpecies({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.primaryImageUrl,
    required this.rarity,
  });
  final String id;
  final String commonName;
  final String? scientificName;
  final String? primaryImageUrl;
  final String? rarity;
}
