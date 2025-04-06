import 'package:flutter/material.dart';
import '../models/year.dart';
import '../services/year_service.dart';

class YearManagementDialog extends StatefulWidget {
  final YearService yearService;

  const YearManagementDialog({super.key, required this.yearService});

  @override
  State<YearManagementDialog> createState() => _YearManagementDialogState();
}

class _YearManagementDialogState extends State<YearManagementDialog> {
  late List<Year> years;
  final TextEditingController _newYearController = TextEditingController();

  @override
  void initState() {
    super.initState();
    years = widget.yearService.getYears();
  }

  void _addYear() {
    if (_newYearController.text.isEmpty) return;

    final newYear = Year(
      id: _newYearController.text,
      name: _newYearController.text,
      createdAt: DateTime.now(),
    );

    setState(() {
      years.add(newYear);
      widget.yearService.saveYears(years);
    });

    _newYearController.clear();
  }

  void _removeYear(String id) {
    setState(() {
      years.removeWhere((year) => year.id == id);
      widget.yearService.saveYears(years);
    });
  }

  @override
  Widget build(BuildContext context) {
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _addYear, child: const Text('Add')),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: years.length,
                  itemBuilder: (context, index) {
                    final year = years[index];
                    return ListTile(
                      title: Text(year.name),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _removeYear(year.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pop(years), // Return updated years
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
