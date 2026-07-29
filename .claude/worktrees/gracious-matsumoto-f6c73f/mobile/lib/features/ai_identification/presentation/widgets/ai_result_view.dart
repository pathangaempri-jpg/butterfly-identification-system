import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/cards/rarity_badge.dart';
import '../../../../shared/widgets/confidence_meter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/a11y.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../observations/data/models/observation.dart';
import '../../../observations/data/repositories/observation_repository.dart';
import '../../../observations/presentation/providers/observation_providers.dart';
import '../../data/models/ai_result.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// AI RESULT VIEW
/// Cinematic reveal of the identification result: confidence gauge, top match,
/// ranked alternatives, and actions. Handles the no-match / failed states too.
/// ─────────────────────────────────────────────────────────────────────────────

class AiResultView extends ConsumerWidget {
  const AiResultView({
    super.key,
    required this.result,
    required this.observationId,
    required this.onScanAgain,
  });

  final AiResult result;
  final String observationId;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (result.isFailed || result.hasNoMatch) {
      return _NoMatchView(
        message: result.errorMessage,
        observationId: observationId,
        onScanAgain: onScanAgain,
      );
    }

    final top = result.topMatch!;
    final tier = ConfidenceTier.fromValue(top.confidenceScore);

    return ListView(
      padding: const EdgeInsets.all(SpaceTokens.lg),
      children: [
        // ── Image Quality / Detection ───────────────────────────────────────
        if (result.imageQuality != null || result.detection != null)
          Center(
            child: Wrap(
              spacing: 8,
              children: [
                if (result.imageQuality?['rating'] != null)
                  Chip(
                    label: Text('Quality: ${result.imageQuality!['rating']}'),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    labelStyle: TypographyTokens.textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                  ),
                if (result.detection?['life_stage'] != null && result.detection?['life_stage'] != '')
                  Chip(
                    label: Text('Stage: ${result.detection!['life_stage']}'),
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    labelStyle: TypographyTokens.textTheme.labelSmall,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        const SizedBox(height: SpaceTokens.md),

        // ── Confidence gauge ────────────────────────────────────────────────
        Center(
          child: ConfidenceMeter(value: top.confidenceScore, size: 150),
        ).animate().fadeIn(duration: 400.ms).scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              curve: Curves.easeOutBack,
            ),
        const SizedBox(height: SpaceTokens.lg),

        // ── Top match ───────────────────────────────────────────────────────
        Center(
          child: Text(
            tier == ConfidenceTier.uncertain
                ? 'Best guess'
                : "It's likely a",
            style: TypographyTokens.textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
          ),
        ).animate().fadeIn(delay: 500.ms),
        const SizedBox(height: SpaceTokens.xs),
        Center(
          child: Text(
            top.displayCommonName,
            textAlign: TextAlign.center,
            style: TypographyTokens.heroTitle.copyWith(
              fontSize: 30,
              color: Theme.of(context).colorScheme.onSurface,
              shadows: const [],
            ),
          ),
        ).animate().fadeIn(delay: 650.ms).moveY(begin: 12, end: 0),
        if (top.displayScientificName.isNotEmpty)
          Center(
            child: Text(
              top.displayScientificName,
              style: TypographyTokens.scientificName.copyWith(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ).animate().fadeIn(delay: 800.ms),

        const SizedBox(height: SpaceTokens.xl),

        // ── Primary actions ─────────────────────────────────────────────────
        if (top.speciesId != null)
          AppButton(
            label: 'View species',
            icon: Icons.menu_book_outlined,
            onPressed: () =>
                context.push(AppRoutes.speciesDetailPath(top.speciesId!)),
          ).animate().fadeIn(delay: 950.ms),
        const SizedBox(height: SpaceTokens.sm),
        AppButton(
          label: 'View my sighting',
          variant: AppButtonVariant.outline,
          icon: Icons.photo_outlined,
          onPressed: () =>
              context.push(AppRoutes.observationDetailPath(observationId)),
        ).animate().fadeIn(delay: 1050.ms),

        _PrivacyToggle(observationId: observationId)
            .animate()
            .fadeIn(delay: 1100.ms),

        // ── Alternatives ────────────────────────────────────────────────────
        if (result.alternatives.isNotEmpty) ...[
          const SizedBox(height: SpaceTokens.xl),
          Text('Other possibilities',
              style: TypographyTokens.textTheme.titleMedium),
          const SizedBox(height: SpaceTokens.sm),
          ...result.alternatives.asMap().entries.map((e) {
            return _AltMatchCard(match: e.value)
                .animate()
                .fadeIn(delay: (1150 + e.key * 100).ms)
                .moveX(begin: 16, end: 0);
          }),
        ],

        // ── Identification Reasoning ────────────────────────────────────────
        if (result.identificationReason != null)
          _ReasoningCard(reason: result.identificationReason!)
              .animate()
              .fadeIn(delay: 1100.ms)
              .moveY(begin: 16, end: 0),

        // ── Species Insights ────────────────────────────────────────────────
        if (result.speciesProfile != null) ...[
          const SizedBox(height: SpaceTokens.md),
          _SpeciesInsightsCard(profile: result.speciesProfile!)
              .animate()
              .fadeIn(delay: 1200.ms)
              .moveY(begin: 16, end: 0),
        ],

        // ── User Guidance ───────────────────────────────────────────────────
        if (result.userGuidance != null && result.userGuidance!['best_photo_tips'] != null) ...[
          const SizedBox(height: SpaceTokens.xl),
          _UserGuidanceView(guidance: result.userGuidance!)
              .animate()
              .fadeIn(delay: 1300.ms),
        ],

        const SizedBox(height: SpaceTokens.xl),
        TextButton.icon(
          onPressed: onScanAgain,
          icon: const Icon(Icons.refresh),
          label: const Text('Scan another'),
        ),
        const SizedBox(height: SpaceTokens.xxl),
      ],
    );
  }
}

class _ReasoningCard extends StatelessWidget {
  const _ReasoningCard({required this.reason});
  final Map<String, dynamic> reason;

  @override
  Widget build(BuildContext context) {
    final summary = reason['summary'] as String?;
    final features = (reason['key_features'] as List?)?.cast<String>() ?? [];

    return Card(
      margin: const EdgeInsets.only(top: SpaceTokens.lg),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: RadiusTokens.cardBR),
      child: Padding(
        padding: const EdgeInsets.all(SpaceTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: ColorTokens.brandPrimary),
                const SizedBox(width: SpaceTokens.sm),
                Text('Why this match?', style: TypographyTokens.textTheme.titleMedium),
              ],
            ),
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: SpaceTokens.sm),
              Text(summary, style: TypographyTokens.textTheme.bodyMedium),
            ],
            if (features.isNotEmpty) ...[
              const SizedBox(height: SpaceTokens.sm),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(child: Text(f, style: TypographyTokens.textTheme.bodyMedium)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeciesInsightsCard extends StatelessWidget {
  const _SpeciesInsightsCard({required this.profile});
  final Map<String, dynamic> profile;

  @override
  Widget build(BuildContext context) {
    final description = profile['description'] as String?;
    final taxonomy = profile['taxonomy'] as Map<String, dynamic>?;
    final physical = profile['physical_characteristics'] as Map<String, dynamic>?;
    final habitats = profile['habitat'] as List?;
    final distribution = profile['distribution'] as Map<String, dynamic>?;
    final seasonality = profile['seasonality'] as Map<String, dynamic>?;
    final hostPlants = profile['host_plants'] as List?;
    final nectarPlants = profile['nectar_plants'] as List?;
    final behavior = profile['behavior'] as Map<String, dynamic>?;
    final lifeCycle = profile['life_cycle'] as Map<String, dynamic>?;
    final lifespan = profile['lifespan'] as String?;
    final conservation = profile['conservation'] as Map<String, dynamic>?;
    final facts = (profile['interesting_facts'] as List?)?.cast<String>() ?? [];
    
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: RadiusTokens.cardBR),
      child: ExpansionTile(
        title: Text('Species Insights', style: TypographyTokens.textTheme.titleMedium),
        leading: const Icon(Icons.menu_book, color: ColorTokens.brandPrimary),
        shape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(SpaceTokens.lg, 0, SpaceTokens.lg, SpaceTokens.lg),
        children: [
          // ── Description ───────────────────────────────────────────────────
          if (description != null && description.isNotEmpty) ...[
            Text(
              description,
              style: TypographyTokens.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: SpaceTokens.md),
          ],

          // ── Taxonomy ──────────────────────────────────────────────────────
          if (taxonomy != null) ...[
            _SectionSubtitle('Taxonomy', Icons.category_outlined),
            _InsightRow('Class', taxonomy['class']),
            _InsightRow('Order', taxonomy['order']),
            _InsightRow('Family', taxonomy['family']),
            _InsightRow('Genus', taxonomy['genus']),
            _InsightRow('Species', taxonomy['species']),
            const Divider(height: SpaceTokens.lg),
          ],

          // ── Physical Characteristics ──────────────────────────────────────
          if (physical != null) ...[
            _SectionSubtitle('Physical Characteristics', Icons.straighten),
            _InsightRow('Wingspan', physical['average_wingspan_cm']),
            _InsightRow('Dimorphism', physical['sexual_dimorphism']),
            if (physical['male_description'] != null)
              _InsightRow('Male Details', physical['male_description']),
            if (physical['female_description'] != null)
              _InsightRow('Female Details', physical['female_description']),
            const Divider(height: SpaceTokens.lg),
          ],

          // ── Habitat & Range ───────────────────────────────────────────────
          if (habitats != null || distribution != null) ...[
            _SectionSubtitle('Habitat & Distribution', Icons.public),
            if (habitats != null && habitats.isNotEmpty)
              _InsightRow('Habitats', habitats.join(', ')),
            if (distribution != null) ...[
              if (distribution['countries'] != null)
                _InsightRow('Countries', (distribution['countries'] as List).join(', ')),
              if (distribution['regions'] != null)
                _InsightRow('Regions', (distribution['regions'] as List).join(', ')),
              _InsightRow('Native status', distribution['native'] == true ? 'Native' : 'Introduced/Migrant'),
            ],
            const Divider(height: SpaceTokens.lg),
          ],

          // ── Food Plants ───────────────────────────────────────────────────
          if ((hostPlants != null && hostPlants.isNotEmpty) || (nectarPlants != null && nectarPlants.isNotEmpty)) ...[
            _SectionSubtitle('Diet & Host Plants', Icons.local_florist_outlined),
            if (hostPlants != null && hostPlants.isNotEmpty)
              _InsightRow('Host Plants', hostPlants.join(', ')),
            if (nectarPlants != null && nectarPlants.isNotEmpty)
              _InsightRow('Nectar Plants', nectarPlants.join(', ')),
            const Divider(height: SpaceTokens.lg),
          ],

          // ── Behavior ──────────────────────────────────────────────────────
          if (behavior != null) ...[
            _SectionSubtitle('Behavior', Icons.directions_run),
            _InsightRow('Flight pattern', behavior['flight_pattern']),
            _InsightRow('Feeding', behavior['feeding']),
            _InsightRow('Migration', behavior['migration']),
            _InsightRow('Activity', behavior['activity']),
            const Divider(height: SpaceTokens.lg),
          ],

          // ── Life Cycle & Seasonality ─────────────────────────────────────
          if (lifeCycle != null || seasonality != null || lifespan != null) ...[
            _SectionSubtitle('Life Cycle & Seasonality', Icons.loop),
            if (seasonality != null) ...[
              _InsightRow('Peak season', seasonality['peak_season']),
              if (seasonality['active_months'] != null)
                _InsightRow('Active months', (seasonality['active_months'] as List).join(', ')),
            ],
            if (lifespan != null)
              _InsightRow('Lifespan', lifespan),
            if (lifeCycle != null) ...[
              if (lifeCycle['egg'] != null) _InsightRow('Egg stage', lifeCycle['egg']),
              if (lifeCycle['larva'] != null) _InsightRow('Larva/Caterpillar', lifeCycle['larva']),
              if (lifeCycle['pupa'] != null) _InsightRow('Pupa/Chrysalis', lifeCycle['pupa']),
              if (lifeCycle['adult'] != null) _InsightRow('Adult stage', lifeCycle['adult']),
            ],
            const Divider(height: SpaceTokens.lg),
          ],

          // ── Conservation ──────────────────────────────────────────────────
          if (conservation != null) ...[
            _SectionSubtitle('Conservation & Rarity', Icons.shield_outlined),
            _InsightRow('Status', conservation['status']),
            _InsightRow('Population trend', conservation['population_trend']),
            _InsightRow('Rare status', conservation['rare'] == true ? 'Yes' : 'No'),
            _InsightRow('Protected status', conservation['protected'] == true ? 'Yes' : 'No'),
            const Divider(height: SpaceTokens.lg),
          ],

          // ── Interesting Facts ─────────────────────────────────────────────
          if (facts.isNotEmpty) ...[
            _SectionSubtitle('Interesting Facts', Icons.lightbulb_outline),
            ...facts.map((f) => Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.star, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(f, style: TypographyTokens.textTheme.bodyMedium)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _SectionSubtitle extends StatelessWidget {
  const _SectionSubtitle(this.title, this.icon);
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpaceTokens.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: SpaceTokens.xs),
          Text(
            title,
            style: TypographyTokens.textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow(this.label, this.value);
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TypographyTokens.textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: SpaceTokens.md),
          Expanded(
            child: Text(
              value.toString(),
              textAlign: TextAlign.right,
              style: TypographyTokens.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserGuidanceView extends StatelessWidget {
  const _UserGuidanceView({required this.guidance});
  final Map<String, dynamic> guidance;

  @override
  Widget build(BuildContext context) {
    final tips = guidance['best_photo_tips'] as String?;
    if (tips == null || tips.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(SpaceTokens.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(76),
        borderRadius: BorderRadius.circular(RadiusTokens.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.camera_alt_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: SpaceTokens.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Photo Tip', style: TypographyTokens.textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
                const SizedBox(height: 4),
                Text(tips, style: TypographyTokens.textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AltMatchCard extends StatelessWidget {
  const _AltMatchCard({required this.match});
  final AiMatch match;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: RadiusTokens.cardBR,
      onTap: match.speciesId == null
          ? null
          : () => context.push(AppRoutes.speciesDetailPath(match.speciesId!)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SpaceTokens.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(RadiusTokens.md),
              child: SizedBox(
                width: 52,
                height: 52,
                child: match.imageUrl == null
                    ? Container(
                        color: ColorTokens.brandPrimary.withAlpha(30),
                        child: const Icon(Icons.flutter_dash,
                            color: ColorTokens.brandPrimary),
                      )
                    : CachedNetworkImage(
                        imageUrl: match.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 256),
              ),
            ),
            const SizedBox(width: SpaceTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.displayCommonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypographyTokens.textTheme.titleSmall),
                  const SizedBox(height: SpaceTokens.xs),
                  ConfidenceBar(value: match.confidenceScore, animate: false),
                ],
              ),
            ),
            if (match.rarity != null) ...[
              const SizedBox(width: SpaceTokens.sm),
              RarityBadge(tier: RarityTier.fromString(match.rarity), compact: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoMatchView extends StatelessWidget {
  const _NoMatchView({
    required this.message,
    required this.observationId,
    required this.onScanAgain,
  });

  final String? message;
  final String observationId;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(SpaceTokens.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ColorTokens.warning.withAlpha(30),
            ),
            child: const Icon(Icons.search_off,
                size: 42, color: ColorTokens.warning),
          ),
          const SizedBox(height: SpaceTokens.lg),
          Text("Couldn't identify it",
              style: TypographyTokens.textTheme.headlineSmall,
              textAlign: TextAlign.center),
          const SizedBox(height: SpaceTokens.sm),
          Text(
            message ??
                'The AI couldn\'t confidently match this photo. Try a clearer, '
                    'closer shot with the wings visible.',
            textAlign: TextAlign.center,
            style: TypographyTokens.textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SpaceTokens.xl),
          AppButton(
            label: 'Try another photo',
            icon: Icons.refresh,
            onPressed: onScanAgain,
          ),
          const SizedBox(height: SpaceTokens.sm),
          AppButton(
            label: 'View my sighting',
            variant: AppButtonVariant.outline,
            onPressed: () =>
                context.push(AppRoutes.observationDetailPath(observationId)),
          ),
        ],
      ),
    );
  }
}

class _PrivacyToggle extends ConsumerStatefulWidget {
  const _PrivacyToggle({required this.observationId});
  final String observationId;

  @override
  ConsumerState<_PrivacyToggle> createState() => _PrivacyToggleState();
}

class _PrivacyToggleState extends ConsumerState<_PrivacyToggle> {
  bool _isLoading = false;

  Future<void> _togglePrivacy(bool makePublic) async {
    setState(() => _isLoading = true);
    final newPrivacy = makePublic ? 'public' : 'private';
    
    final result = await ref
        .read(observationRepositoryProvider)
        .updatePrivacy(widget.observationId, newPrivacy);

    if (mounted) {
      setState(() => _isLoading = false);
      result.fold(
        (failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update privacy: ${failure.message}'),
              backgroundColor: ColorTokens.error,
            ),
          );
        },
        (updatedObs) {
          // Invalidate the detail provider to update the observation details
          ref.invalidate(observationDetailProvider(widget.observationId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                makePublic
                    ? 'Identification is now public and shared!'
                    : 'Identification is now private.',
              ),
              backgroundColor: ColorTokens.success,
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final obsAsync = ref.watch(observationDetailProvider(widget.observationId));

    return obsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (obs) {
        final currentUser = ref.watch(currentUserProvider);
        final isOwner = currentUser?.id == obs.userId;

        // Only owner can toggle privacy
        if (!isOwner) return const SizedBox.shrink();

        final isPublic = obs.privacy == 'public';
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          elevation: 0,
          color: colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: RadiusTokens.cardBR),
          margin: const EdgeInsets.only(top: SpaceTokens.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpaceTokens.md,
              vertical: SpaceTokens.sm,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(SpaceTokens.sm),
                  decoration: BoxDecoration(
                    color: isPublic
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.amber.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPublic ? Icons.public : Icons.lock_outline,
                    color: isPublic ? Colors.green : Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: SpaceTokens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPublic ? 'Shared Publicly' : 'Private Sighting',
                        style: TypographyTokens.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isPublic
                            ? 'Visible in the community feed'
                            : 'Only visible to you',
                        style: TypographyTokens.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch(
                    value: isPublic,
                    activeColor: ColorTokens.brandPrimary,
                    onChanged: (val) {
                      Haptics.selection();
                      _togglePrivacy(val);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
