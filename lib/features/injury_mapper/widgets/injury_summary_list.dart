import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/body_region_constants.dart';
import '../../../core/models/injury_entry.dart';
import '../../../core/providers/injury_provider.dart';

/// Grouped list of all recorded injuries with edit/delete actions.
class InjurySummaryList extends StatelessWidget {
  const InjurySummaryList({super.key});

  @override
  Widget build(BuildContext context) {
    final injuryProvider = context.watch<InjuryProvider>();
    final regions = injuryProvider.selectedRegions;

    if (regions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Tap on a body region to add injuries',
            style: TextStyle(color: AppColors.textHint),
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: regions.entries.map((entry) {
        final regionId = entry.key;
        final injuries = entry.value;
        final regionName = BodyRegionConstants.getRegionName(regionId);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ExpansionTile(
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: injuryProvider.getSeverityColor(regionId),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(
              regionName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${injuries.length} ${injuries.length == 1 ? 'injury' : 'injuries'}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            children: injuries.asMap().entries.map((indexedEntry) {
              final index = indexedEntry.key;
              final injury = indexedEntry.value;

              return ListTile(
                dense: true,
                leading: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.severityColor(injury.severity),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  '${injury.type} — ${injury.severity}',
                  style: const TextStyle(fontSize: 14),
                ),
                subtitle: injury.description != null
                    ? Text(
                        injury.description!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: AppColors.error),
                  onPressed: () {
                    context
                        .read<InjuryProvider>()
                        .removeInjury(regionId, index);
                  },
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
