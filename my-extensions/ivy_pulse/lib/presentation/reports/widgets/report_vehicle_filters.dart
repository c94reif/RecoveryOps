import 'package:flutter/material.dart';

class ReportVehicleFilters extends StatelessWidget {
  final TextEditingController searchController;
  final bool faultsOnly;
  final bool unreadOnly;
  final bool showUnread;
  final bool hasVehicleFilters;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<bool> onFaultsChanged;
  final ValueChanged<bool> onUnreadChanged;
  final VoidCallback onClearFilters;

  const ReportVehicleFilters({
    super.key,
    required this.searchController,
    required this.faultsOnly,
    required this.unreadOnly,
    required this.showUnread,
    required this.hasVehicleFilters,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFaultsChanged,
    required this.onUnreadChanged,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          decoration: InputDecoration(
            labelText: 'Search bumper number or UIC',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: onClearSearch,
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, children: [
          FilterChip(
              label: const Text('With faults'),
              selected: faultsOnly,
              onSelected: onFaultsChanged),
          if (showUnread)
            FilterChip(
                label: const Text('Unread'),
                selected: unreadOnly,
                onSelected: onUnreadChanged),
          if (hasVehicleFilters)
            TextButton(
                onPressed: onClearFilters, child: const Text('Clear filters')),
        ]),
      ]),
    );
  }
}
