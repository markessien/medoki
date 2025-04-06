import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Import Riverpod
import '../providers/years_provider.dart'; // Import the years provider
// Removed Year model import as we get it from provider
// Removed YearService import as we use the provider notifier

// Change to ConsumerStatefulWidget
class YearManagementDialog extends ConsumerStatefulWidget {
  // Removed yearService parameter
  const YearManagementDialog({super.key});

  @override
  ConsumerState<YearManagementDialog> createState() =>
      _YearManagementDialogState();
}

// Change to ConsumerState
class _YearManagementDialogState extends ConsumerState<YearManagementDialog> {
  // Removed local years list
  final TextEditingController _newYearController = TextEditingController();

  // initState is no longer needed to load years

  // Use provider notifier to add year
  void _addYear() {
    final yearName = _newYearController.text.trim();
    if (yearName.isEmpty) return;

    // Call the notifier method
    // Use ref.read() inside callbacks/functions
    ref.read(yearsProvider.notifier).addYear(yearName);

    _newYearController.clear();
    // No need for setState as the provider update will trigger rebuilds
  }

  // Use provider notifier to remove year
  void _removeYear(String yearName) {
    // Call the notifier method
    ref.read(yearsProvider.notifier).removeYear(yearName);
    // No need for setState
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider to get the current list of years
    final years = ref.watch(yearsProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Manage Years',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newYearController,
                      decoration: const InputDecoration(
                        labelText: 'New Year',
                        hintText: 'Enter year (e.g., 2024)',
                      ),
                      keyboardType: TextInputType.number,
                      // Add onSubmitted for convenience
                      onSubmitted: (_) => _addYear(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _addYear, child: const Text('Add')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                // Display years from the provider
                child: ListView.builder(
                  itemCount: years.length,
                  itemBuilder: (context, index) {
                    final year = years[index];
                    return ListTile(
                      title: Text(year.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        // Pass year name to remove method
                        onPressed: () => _removeYear(year.name),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                // Just pop the navigator, no need to return data
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _newYearController.dispose();
    super.dispose();
  }
}
