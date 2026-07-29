import 'dart:convert';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart' show Value;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/daos/observations_dao.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../home/data/models/observation_summary.dart';
import '../datasources/observation_remote_datasource.dart';
import '../models/observation.dart';
import '../models/observation_draft.dart';

/// Outcome of a submit attempt.
sealed class SubmitOutcome {
  const SubmitOutcome();
}

class SubmitSuccess extends SubmitOutcome {
  const SubmitSuccess(this.observation);
  final Observation observation;
}

/// Saved to the offline queue; will sync when back online.
class SubmitQueued extends SubmitOutcome {
  const SubmitQueued();
}

/// Reports progress through the multi-step submit pipeline.
typedef SubmitProgress = void Function(SubmitStage stage, double fraction);

enum SubmitStage { compressing, creating, uploading, identifying, done }

/// ─────────────────────────────────────────────────────────────────────────────
/// OBSERVATION REPOSITORY
/// ─────────────────────────────────────────────────────────────────────────────

abstract class IObservationRepository {
  Future<Either<Failure, SubmitOutcome>> submit(
    ObservationDraft draft, {
    SubmitProgress? onProgress,
  });
  Future<Either<Failure, Observation>> getDetail(String id);
  Future<Either<Failure, List<ObservationSummary>>> listMine({int page});
  Future<int> pendingQueueCount();
  Future<void> syncPending();
  Future<Either<Failure, Observation>> updatePrivacy(String id, String privacy);
}

class ObservationRepository implements IObservationRepository {
  ObservationRepository({
    required IObservationRemoteDataSource remote,
    required ObservationsDao dao,
    required IConnectivityService connectivity,
  })  : _remote = remote,
        _dao = dao,
        _connectivity = connectivity;

  final IObservationRemoteDataSource _remote;
  final ObservationsDao _dao;
  final IConnectivityService _connectivity;

  @override
  Future<Either<Failure, SubmitOutcome>> submit(
    ObservationDraft draft, {
    SubmitProgress? onProgress,
  }) async {
    if (!draft.isValid) {
      return const Left(ValidationFailure(
        message: 'Please select a state for your sighting.',
        fieldErrors: {'state_id': ['Required']},
      ));
    }

    // 1. Compress images up front (works offline too).
    onProgress?.call(SubmitStage.compressing, 0);
    final compressed = await ImageHelper.compressAll(draft.images);

    // 2. Offline → enqueue and bail early.
    if (!_connectivity.isOnline) {
      await _enqueue(draft, compressed);
      onProgress?.call(SubmitStage.done, 1);
      return const Right(SubmitQueued());
    }

    try {
      // 3. Create the observation.
      onProgress?.call(SubmitStage.creating, 0.1);
      final obs = await _remote.create(draft.toCreateJson());

      // 4. Upload images sequentially (one per request).
      for (var i = 0; i < compressed.length; i++) {
        onProgress?.call(
          SubmitStage.uploading,
          0.2 + (0.6 * (i / (compressed.length == 0 ? 1 : compressed.length))),
        );
        await _remote.uploadImage(obs.id, compressed[i]);
      }

      // 5. Trigger AI identification (best-effort).
      onProgress?.call(SubmitStage.identifying, 0.9);
      try {
        await _remote.triggerIdentify(obs.id);
      } catch (_) {/* identification is non-blocking */}

      onProgress?.call(SubmitStage.done, 1);
      return Right(SubmitSuccess(obs));
    } on AppException catch (e) {
      // Network dropped mid-flight → queue for later.
      if (e is NetworkException || e is TimeoutException) {
        await _enqueue(draft, compressed);
        return const Right(SubmitQueued());
      }
      return Left(e.toFailure());
    } catch (e) {
      return Left(ExceptionMapper.fromObject(e).toFailure());
    }
  }

  @override
  Future<Either<Failure, Observation>> getDetail(String id) async {
    try {
      return Right(await _remote.getDetail(id));
    } on AppException catch (e) {
      return Left(e.toFailure());
    } catch (e) {
      return Left(ExceptionMapper.fromObject(e).toFailure());
    }
  }

  @override
  Future<Either<Failure, List<ObservationSummary>>> listMine({
    int page = 1,
  }) async {
    try {
      return Right(await _remote.listMine(page: page));
    } on AppException catch (e) {
      return Left(e.toFailure());
    } catch (e) {
      return Left(ExceptionMapper.fromObject(e).toFailure());
    }
  }

  @override
  Future<int> pendingQueueCount() => _dao.getPendingCount();

  /// Drains the offline queue when connectivity is available.
  ///
  /// Robustness:
  ///  - recovers rows stuck in 'processing' from an interrupted run,
  ///  - treats failures as retryable (via [ObservationsDao.incrementRetry]) so a
  ///    transient network drop doesn't permanently discard a queued sighting;
  ///    only after `maxRetries` does a row become 'failed'.
  @override
  Future<void> syncPending() async {
    if (!_connectivity.isOnline) return;

    // Re-queue anything a previous (crashed) drain left mid-flight.
    await _dao.resetProcessingToPending();

    final pending = await _dao.getPendingQueue();
    for (final row in pending) {
      try {
        await _dao.markProcessing(row.localId);
        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        final paths =
            (jsonDecode(row.localImagePaths ?? '[]') as List).cast<String>();

        final obs = await _remote.create(payload);
        for (final path in paths) {
          final file = File(path);
          if (file.existsSync()) await _remote.uploadImage(obs.id, file);
        }
        try {
          await _remote.triggerIdentify(obs.id);
        } catch (_) {}
        await _dao.markSucceeded(row.localId);
      } catch (_) {
        // Retryable: incrementRetry resets to 'pending' until maxRetries,
        // after which the row is marked 'failed'.
        await _dao.incrementRetry(row.localId);
      }
    }
    await _dao.clearSucceeded();
  }

  // ── Offline queue ────────────────────────────────────────────────────────

  Future<void> _enqueue(ObservationDraft draft, List<File> images) async {
    await _dao.addToQueue(
      OfflineQueueTableCompanion(
        type: const Value('observation'),
        endpoint: const Value('/api/v1/observations/'),
        httpMethod: const Value('POST'),
        payload: Value(jsonEncode(draft.toCreateJson())),
        hasImages: Value(images.isNotEmpty),
        localImagePaths:
            Value(jsonEncode(images.map((f) => f.path).toList())),
        status: const Value('pending'),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<Either<Failure, Observation>> updatePrivacy(
    String id,
    String privacy,
  ) async {
    try {
      final obs = await _remote.updatePrivacy(id, privacy);
      return Right(obs);
    } on AppException catch (e) {
      return Left(e.toFailure());
    } catch (e) {
      return Left(ExceptionMapper.fromObject(e).toFailure());
    }
  }
}
