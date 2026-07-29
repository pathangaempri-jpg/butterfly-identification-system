import 'package:dio/dio.dart';
import '../../../../core/api/api_endpoints.dart';
import '../models/ai_result.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AI REMOTE DATASOURCE
/// `trigger` runs Gemini synchronously server-side (5–15s) and returns the
/// completed result, so no client-side polling is required.
/// ─────────────────────────────────────────────────────────────────────────────

abstract class IAiRemoteDataSource {
  Future<AiResult> triggerIdentify(String observationId);
  Future<AiResult> getResult(String observationId);
}

class AiRemoteDataSource implements IAiRemoteDataSource {
  AiRemoteDataSource({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Map<String, dynamic> _obj(Response<dynamic> res) {
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    return <String, dynamic>{};
  }

  @override
  Future<AiResult> triggerIdentify(String observationId) async {
    final res = await _dio.post<dynamic>(
      ApiEndpoints.observationIdentify(observationId),
      // Gemini call is inline — allow generous time beyond the default.
      options: Options(receiveTimeout: const Duration(seconds: 40)),
    );
    return AiResult.fromJson(_obj(res));
  }

  @override
  Future<AiResult> getResult(String observationId) async {
    final res = await _dio.get<dynamic>(
      ApiEndpoints.observationIdentifyResult(observationId),
    );
    return AiResult.fromJson(_obj(res));
  }
}
