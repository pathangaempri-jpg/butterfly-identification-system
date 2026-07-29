import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/color_tokens.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/theme/typography_tokens.dart';
import '../../../../core/utils/a11y.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/widgets/inputs/app_text_field.dart';
import '../../../geography/data/geography_models.dart';
import '../../../geography/presentation/geography_providers.dart';
import '../../data/models/observation.dart';
import '../../data/models/observation_draft.dart';
import '../../data/repositories/observation_repository.dart' show SubmitStage;
import '../providers/observation_providers.dart';
import '../widgets/image_picker_grid.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// SUBMIT OBSERVATION SCREEN
/// ─────────────────────────────────────────────────────────────────────────────

class SubmitObservationScreen extends ConsumerStatefulWidget {
  const SubmitObservationScreen({super.key});

  @override
  ConsumerState<SubmitObservationScreen> createState() =>
      _SubmitObservationScreenState();
}

class _SubmitObservationScreenState
    extends ConsumerState<SubmitObservationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _locationController = TextEditingController();

  final _draft = ObservationDraft();

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_draft.stateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a state.')),
      );
      return;
    }
    Haptics.medium();
    _draft
      ..title = _titleController.text
      ..notes = _notesController.text
      ..locationName = _locationController.text;
    ref.read(submitNotifierProvider.notifier).submit(_draft);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(submitNotifierProvider);

    ref.listen<SubmitState>(submitNotifierProvider, (prev, next) {
      if (next.status == SubmitStatus.success) {
        Haptics.success();
        _showSuccess(next.observation);
      } else if (next.status == SubmitStatus.queued) {
        Haptics.success();
        _showQueued();
      } else if (next.status == SubmitStatus.error) {
        Haptics.error();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(next.error ?? 'Could not submit sighting.'),
            backgroundColor: ColorTokens.error,
            behavior: SnackBarBehavior.floating,
          ));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Submit a Sighting')),
      body: AbsorbPointer(
        absorbing: state.isSubmitting,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(SpaceTokens.base),
            children: [
              const _SectionLabel('Photos', hint: 'optional but recommended'),
              ImagePickerGrid(
                images: _draft.images,
                onChanged: (imgs) => setState(() => _draft.images = imgs),
              ),
              const SizedBox(height: SpaceTokens.lg),

              const _SectionLabel('Details'),
              AppTextField(
                label: 'Title',
                hint: 'e.g. Crimson Rose near Munnar',
                controller: _titleController,
              ),
              const SizedBox(height: SpaceTokens.md),
              AppTextField(
                label: 'Notes',
                hint: 'Behaviour, wing condition, flowers it fed on…',
                controller: _notesController,
                maxLines: 3,
              ),
              const SizedBox(height: SpaceTokens.md),

              // State picker (required)
              _StatePicker(
                selectedId: _draft.stateId,
                onSelected: (s) => setState(() {
                  _draft.stateId = s.id;
                  _draft.districtId = null; // reset district
                }),
              ),
              const SizedBox(height: SpaceTokens.md),

              // District picker (depends on state)
              if (_draft.stateId != null)
                _DistrictPicker(
                  stateId: _draft.stateId!,
                  selectedId: _draft.districtId,
                  onSelected: (d) =>
                      setState(() => _draft.districtId = d?.id),
                ),
              if (_draft.stateId != null) const SizedBox(height: SpaceTokens.md),

              AppTextField(
                label: 'Location name',
                hint: 'e.g. Bandipur Forest',
                controller: _locationController,
              ),
              const SizedBox(height: SpaceTokens.md),

              _DateField(
                date: _draft.observedAt,
                onPick: (d) => setState(() => _draft.observedAt = d),
              ),
              const SizedBox(height: SpaceTokens.lg),

              const _SectionLabel('Conditions', hint: 'optional'),
              _WeatherSelector(
                selected: _draft.weather,
                onSelected: (w) => setState(() => _draft.weather = w),
              ),
              const SizedBox(height: SpaceTokens.md),
              _ActivitySelector(
                selected: _draft.activity,
                onSelected: (a) => setState(() => _draft.activity = a),
              ),
              const SizedBox(height: SpaceTokens.md),
              _CountStepper(
                count: _draft.countObserved,
                onChanged: (c) => setState(() => _draft.countObserved = c),
              ),
              const SizedBox(height: SpaceTokens.lg),

              const _SectionLabel('Privacy'),
              _PrivacySelector(
                selected: _draft.privacy,
                onSelected: (p) => setState(() => _draft.privacy = p),
              ),
              const SizedBox(height: SpaceTokens.xl),

              if (state.isSubmitting)
                _SubmitProgress(stage: state.stage, progress: state.progress)
              else
                AppButton(
                  label: 'Submit Sighting',
                  icon: Icons.send,
                  onPressed: _submit,
                ),
              const SizedBox(height: SpaceTokens.xxl),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess(Observation? obs) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        icon: const Icon(Icons.check_circle,
            color: ColorTokens.success, size: 48),
        title: const Text('Sighting submitted!'),
        content: const Text(
          'Your observation was uploaded. Our AI is analysing the photo to '
          'identify the species.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dctx).pop();
              ref.read(submitNotifierProvider.notifier).reset();
              if (obs != null) {
                context.pushReplacement(
                    AppRoutes.observationDetailPath(obs.id));
              } else {
                context.pop();
              }
            },
            child: const Text('View Sighting'),
          ),
        ],
      ),
    );
  }

  void _showQueued() {
    showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        icon: const Icon(Icons.cloud_off,
            color: ColorTokens.warning, size: 48),
        title: const Text('Saved offline'),
        content: const Text(
          "You're offline, so we saved this sighting on your device. "
          "It'll upload automatically when you're back online.",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dctx).pop();
              ref.read(submitNotifierProvider.notifier).reset();
              context.pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: SpaceTokens.sm),
        child: Row(
          children: [
            Text(text, style: TypographyTokens.textTheme.titleMedium),
            if (hint != null) ...[
              const SizedBox(width: SpaceTokens.sm),
              Text('($hint)',
                  style: TypographyTokens.caption.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ],
          ],
        ),
      );
}

// ── State picker ─────────────────────────────────────────────────────────────

class _StatePicker extends ConsumerWidget {
  const _StatePicker({required this.selectedId, required this.onSelected});
  final int? selectedId;
  final ValueChanged<IndiaState> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statesAsync = ref.watch(statesProvider);
    return statesAsync.when(
      loading: () => const _PickerSkeleton(label: 'State *'),
      error: (_, __) => const Text('Could not load states'),
      data: (states) => DropdownButtonFormField<int>(
        initialValue: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'State *'),
        hint: const Text('Select state'),
        items: states
            .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
            .toList(),
        onChanged: (id) {
          if (id == null) return;
          onSelected(states.firstWhere((s) => s.id == id));
        },
        validator: (v) => v == null ? 'Please select a state' : null,
      ),
    );
  }
}

class _DistrictPicker extends ConsumerWidget {
  const _DistrictPicker({
    required this.stateId,
    required this.selectedId,
    required this.onSelected,
  });
  final int stateId;
  final int? selectedId;
  final ValueChanged<IndiaDistrict?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final districtsAsync = ref.watch(districtsProvider(stateId));
    return districtsAsync.when(
      loading: () => const _PickerSkeleton(label: 'District'),
      error: (_, __) => const SizedBox.shrink(),
      data: (districts) {
        if (districts.isEmpty) return const SizedBox.shrink();
        return DropdownButtonFormField<int>(
          initialValue: selectedId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'District (optional)'),
          hint: const Text('Select district'),
          items: districts
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
              .toList(),
          onChanged: (id) => onSelected(
            id == null ? null : districts.firstWhere((d) => d.id == id),
          ),
        );
      },
    );
  }
}

class _PickerSkeleton extends StatelessWidget {
  const _PickerSkeleton({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: const SizedBox(
          height: 20,
          child: Center(
              child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )),
        ),
      );
}

// ── Date ─────────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({required this.date, required this.onPick});
  final DateTime? date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date observed (optional)',
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          date == null
              ? 'Select date'
              : '${date!.day}/${date!.month}/${date!.year}',
          style: TypographyTokens.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

// ── Weather / Activity / Count / Privacy ─────────────────────────────────────

class _WeatherSelector extends StatelessWidget {
  const _WeatherSelector({required this.selected, required this.onSelected});
  final Weather? selected;
  final ValueChanged<Weather> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: SpaceTokens.sm,
        runSpacing: SpaceTokens.sm,
        children: Weather.values.map((w) {
          return ChoiceChip(
            label: Text('${w.emoji} ${w.label}'),
            selected: selected == w,
            onSelected: (_) => onSelected(w),
          );
        }).toList(),
      );
}

class _ActivitySelector extends StatelessWidget {
  const _ActivitySelector({required this.selected, required this.onSelected});
  final ButterflyActivity? selected;
  final ValueChanged<ButterflyActivity> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: SpaceTokens.sm,
        runSpacing: SpaceTokens.sm,
        children: ButterflyActivity.values.map((a) {
          return ChoiceChip(
            label: Text(a.label),
            selected: selected == a,
            onSelected: (_) => onSelected(a),
          );
        }).toList(),
      );
}

class _CountStepper extends StatelessWidget {
  const _CountStepper({required this.count, required this.onChanged});
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Count observed',
            style: TypographyTokens.textTheme.bodyLarge),
        const Spacer(),
        IconButton.outlined(
          onPressed: count > 1 ? () => onChanged(count - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text('$count',
              textAlign: TextAlign.center,
              style: TypographyTokens.textTheme.titleMedium),
        ),
        IconButton.outlined(
          onPressed: count < 9999 ? () => onChanged(count + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _PrivacySelector extends StatelessWidget {
  const _PrivacySelector({required this.selected, required this.onSelected});
  final ObservationPrivacy selected;
  final ValueChanged<ObservationPrivacy> onSelected;

  @override
  Widget build(BuildContext context) => Column(
        children: ObservationPrivacy.values.map((p) {
          final isSelected = selected == p;
          return Padding(
            padding: const EdgeInsets.only(bottom: SpaceTokens.sm),
            child: InkWell(
              borderRadius: RadiusTokens.buttonBR,
              onTap: () => onSelected(p),
              child: Container(
                padding: const EdgeInsets.all(SpaceTokens.md),
                decoration: BoxDecoration(
                  borderRadius: RadiusTokens.buttonBR,
                  color: isSelected
                      ? ColorTokens.brandPrimary.withValues(alpha: 0.08)
                      : null,
                  border: Border.all(
                    color: isSelected
                        ? ColorTokens.brandPrimary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? ColorTokens.brandPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: SpaceTokens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label,
                              style: TypographyTokens.textTheme.titleSmall),
                          Text(p.description,
                              style: TypographyTokens.caption.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// ── Submit progress ──────────────────────────────────────────────────────────

class _SubmitProgress extends StatelessWidget {
  const _SubmitProgress({required this.stage, required this.progress});
  final SubmitStage? stage;
  final double progress;

  String get _label => switch (stage) {
        SubmitStage.compressing => 'Optimising photos…',
        SubmitStage.creating => 'Creating sighting…',
        SubmitStage.uploading => 'Uploading photos…',
        SubmitStage.identifying => 'Starting AI identification…',
        SubmitStage.done => 'Done',
        null => 'Submitting…',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress == 0 ? null : progress,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: SpaceTokens.sm),
        Text(_label, style: TypographyTokens.textTheme.bodyMedium),
      ],
    );
  }
}
