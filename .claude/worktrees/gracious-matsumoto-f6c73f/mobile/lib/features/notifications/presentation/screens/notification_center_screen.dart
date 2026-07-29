import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../../core/utils/a11y.dart';
import '../../../../shared/widgets/loaders/skeleton.dart';
import '../../../../shared/widgets/states/empty_state.dart';
import '../../data/models/app_notification.dart';
import '../notification_providers.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// NOTIFICATION CENTER SCREEN
/// ─────────────────────────────────────────────────────────────────────────────

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 300) {
        ref.read(notificationsNotifierProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onTap(AppNotification n) {
    Haptics.light();
    if (!n.isRead) {
      ref.read(notificationsNotifierProvider.notifier).markRead(n.id);
    }
    if (n.observationId != null) {
      context.push(AppRoutes.observationDetailPath(n.observationId!));
    } else if (n.speciesId != null) {
      context.push(AppRoutes.speciesDetailPath(n.speciesId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationsNotifierProvider.notifier)
                  .markAllRead(),
              child: const Text('Mark all read'),
            ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Notification settings',
            onPressed: () => context.push(AppRoutes.notificationPreferences),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationsNotifierProvider.notifier).refresh(),
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildBody(NotificationsState state) {
    if (state.isInitialLoading) {
      return ListView(
        padding: const EdgeInsets.all(SpaceTokens.base),
        children: List.generate(
          7,
          (_) => const Padding(
            padding: EdgeInsets.symmetric(vertical: SpaceTokens.xs),
            child: ListTileSkeleton(),
          ),
        ),
      );
    }

    if (state.hasError && state.items.isEmpty) {
      return AppEmptyState.error(
        message: state.error,
        onRetry: () =>
            ref.read(notificationsNotifierProvider.notifier).refresh(),
      );
    }

    if (state.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.2),
          const AppEmptyState(
            icon: Icons.notifications_none,
            title: "You're all caught up",
            message: 'New notifications will show up here.',
          ),
        ],
      );
    }

    final groups = _group(state.items);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: SpaceTokens.xxl),
      itemCount: groups.length + (state.status == NotificationsStatus.loadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= groups.length) {
          return const Padding(
            padding: EdgeInsets.all(SpaceTokens.base),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final group = groups[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SpaceTokens.base, SpaceTokens.base, SpaceTokens.base, SpaceTokens.xs),
              child: Text(group.label,
                  style: TypographyTokens.textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ),
            ...group.items.map((n) => Dismissible(
                  key: ValueKey(n.id),
                  direction: n.isRead
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  onDismissed: (_) => ref
                      .read(notificationsNotifierProvider.notifier)
                      .markRead(n.id),
                  background: Container(
                    color: ColorTokens.brandPrimary.withValues(alpha: 0.1),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: SpaceTokens.lg),
                    child: const Icon(Icons.done_all,
                        color: ColorTokens.brandPrimary),
                  ),
                  child: _NotificationTile(notification: n, onTap: () => _onTap(n)),
                )),
          ],
        );
      },
    );
  }

  List<_Group> _group(List<AppNotification> items) {
    final now = DateTime.now();
    final today = <AppNotification>[];
    final week = <AppNotification>[];
    final earlier = <AppNotification>[];
    for (final n in items) {
      final d = n.createdAt;
      if (d == null) {
        earlier.add(n);
        continue;
      }
      final diff = now.difference(d);
      if (diff.inDays == 0 && d.day == now.day) {
        today.add(n);
      } else if (diff.inDays < 7) {
        week.add(n);
      } else {
        earlier.add(n);
      }
    }
    return [
      if (today.isNotEmpty) _Group('Today', today),
      if (week.isNotEmpty) _Group('This week', week),
      if (earlier.isNotEmpty) _Group('Earlier', earlier),
    ];
  }
}

class _Group {
  _Group(this.label, this.items);
  final String label;
  final List<AppNotification> items;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kind = notification.kind;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead
            ? null
            : ColorTokens.brandPrimary.withValues(alpha: 0.04),
        padding: const EdgeInsets.symmetric(
            horizontal: SpaceTokens.base, vertical: SpaceTokens.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kind.color.withValues(alpha: 0.15),
              ),
              child: Icon(kind.icon, size: 20, color: kind.color),
            ),
            const SizedBox(width: SpaceTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TypographyTokens.textTheme.titleSmall?.copyWith(
                      fontWeight:
                          notification.isRead ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                  if (notification.body.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TypographyTokens.textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: TypographyTokens.caption.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6, left: SpaceTokens.sm),
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: ColorTokens.brandPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
