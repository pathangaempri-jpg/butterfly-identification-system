import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/theme/color_tokens.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// APP NOTIFICATION
/// Matches Notification.to_dict() from the backend.
/// ─────────────────────────────────────────────────────────────────────────────

@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    required String id,
    @Default('system') String type,
    @Default('') String title,
    @Default('') String body,
    Map<String, dynamic>? data,
    @JsonKey(name: 'is_read') @Default(false) bool isRead,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _AppNotification;

  const AppNotification._();

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);

  NotificationKind get kind => NotificationKind.fromType(type);

  /// Deep-link target id pulled from the payload, if present.
  String? get speciesId => data?['species_id'] as String?;
  String? get observationId => data?['observation_id'] as String?;
}

/// Visual + routing classification derived from the backend `type` string.
enum NotificationKind {
  identification(Icons.auto_awesome, ColorTokens.brandSecondary),
  social(Icons.favorite, ColorTokens.error),
  achievement(Icons.emoji_events, ColorTokens.goldBadge),
  nearby(Icons.place, ColorTokens.brandPrimary),
  system(Icons.notifications, ColorTokens.rarityCommon);

  const NotificationKind(this.icon, this.color);
  final IconData icon;
  final Color color;

  static NotificationKind fromType(String type) {
    final t = type.toLowerCase();
    if (t.contains('identif')) return NotificationKind.identification;
    if (t.contains('like') || t.contains('comment') || t.contains('follow')) {
      return NotificationKind.social;
    }
    if (t.contains('achiev') ||
        t.contains('badge') ||
        t.contains('streak') ||
        t.contains('level')) {
      return NotificationKind.achievement;
    }
    if (t.contains('nearby') || t.contains('species') || t.contains('event')) {
      return NotificationKind.nearby;
    }
    return NotificationKind.system;
  }
}
