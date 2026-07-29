import 'dart:async';
import 'package:dio/dio.dart';
import 'secure_storage_service.dart';
import '../api/api_endpoints.dart';
import '../errors/app_exception.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TOKEN MANAGER
/// Handles JWT access/refresh lifecycle:
///   - stores tokens in secure storage
///   - exposes read methods for interceptors
///   - implements thread-safe refresh-once pattern
///     (multiple concurrent 401s share one refresh request)
/// ─────────────────────────────────────────────────────────────────────────────

abstract class ITokenManager {
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveTokens({required String accessToken, required String refreshToken});
  Future<void> clearTokens();
  Future<String?> refreshAccessToken(Dio dio);
  bool get isRefreshing;
}

class TokenManager implements ITokenManager {
  TokenManager({required ISecureStorageService storage}) : _storage = storage;

  final ISecureStorageService _storage;

  // ── Refresh-once lock ─────────────────────────────────────────────────────
  // Multiple 401s arrive simultaneously → only one refresh call is made,
  // all waiters share the same future result.
  Completer<String?>? _refreshCompleter;

  @override
  bool get isRefreshing => _refreshCompleter != null && !_refreshCompleter!.isCompleted;

  @override
  Future<String?> getAccessToken() => _storage.getAccessToken();

  @override
  Future<String?> getRefreshToken() => _storage.getRefreshToken();

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.saveAccessToken(accessToken),
      _storage.saveRefreshToken(refreshToken),
    ]);
  }

  @override
  Future<void> clearTokens() => _storage.clearTokens();

  /// Refreshes the access token.
  /// Thread-safe: concurrent calls share one in-flight request.
  @override
  Future<String?> refreshAccessToken(Dio dio) async {
    // If already refreshing, wait for that result
    if (isRefreshing) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const TokenRefreshException(
          message: 'No refresh token stored. Please sign in again.',
        );
      }

      // Use a fresh Dio instance (no interceptors) to avoid recursion
      final refreshDio = Dio(BaseOptions(baseUrl: dio.options.baseUrl));

      final response = await refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      final newAccessToken = data['data']?['access_token'] as String?;
      final newRefreshToken = data['data']?['refresh_token'] as String? ?? refreshToken;

      if (newAccessToken == null || newAccessToken.isEmpty) {
        throw const TokenRefreshException();
      }

      await saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      _refreshCompleter!.complete(newAccessToken);
      return newAccessToken;
    } catch (e) {
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }
}
