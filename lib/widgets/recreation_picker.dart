import 'package:flutter/material.dart';
import '../models/recreation_activities.dart';

/// Activity selector shared by new-place and administrator editing forms.
/// Activity tags require no fee entry and are saved in Place.services.
class RecreationPicker extends StatelessWidget {
  const RecreationPicker({
    super.key,
    required this.selected,
    required this.onToggle,
    this.enabled = true,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text('주변 관광·레저', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 6),
        Text('이 장소에서 즐길 수 있는 활동을 선택하세요. (복수 선택 가능)',
            style: TextStyle(fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final activity in recreationActivities)
              FilterChip(
                label: Text(activity),
                selected: selected.contains(activity),
                onSelected: enabled ? (_) => onToggle(activity) : null,
                showCheckmark: true,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ],
    );
  }
}
