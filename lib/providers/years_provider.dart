import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/year.dart';
import '../services/year_service.dart';
import 'year_service_provider.dart'; // Import the service provider

// StateNotifier for managing the list of years
class YearsNotifier extends StateNotifier<List<Year>> {
  final YearService _yearService;

  YearsNotifier(this._yearService) : super([]) {
    _loadYears(); // Load initial years
  }

  // Load years from the service and sort them
  void _loadYears() {
    final years = _yearService.getYears();
    years.sort((a, b) => _compareYears(a, b)); // Sort initially
    state = years;
  }

  // Helper for consistent sorting
  int _compareYears(Year a, Year b) {
    try {
      return int.parse(b.name).compareTo(int.parse(a.name));
    } catch (e) {
      // Handle potential non-integer year names gracefully
      return a.name.compareTo(b.name); // Fallback to string comparison
    }
  }

  // Add a year, save, and update state
  Future<void> addYear(String yearName) async {
    // Basic validation (optional, can be done in UI too)
    if (yearName.isEmpty || state.any((y) => y.name == yearName)) {
      // Optionally throw an error or return a status
      print("Year already exists or is empty.");
      return;
    }
    final newYear = Year(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple unique ID
      name: yearName,
      createdAt: DateTime.now(), // Current timestamp
    );
    await _yearService.addYear(newYear); // Save using the service
    // Update state immutably and sort
    state = [...state, newYear]..sort((a, b) => _compareYears(a, b));
  }

  // Remove a year, save, and update state
  Future<void> removeYear(String yearName) async {
    // Find the year object to remove
    Year? yearToRemove;
    try {
      yearToRemove = state.firstWhere((y) => y.name == yearName);
    } catch (e) {
      print("Year '$yearName' not found for removal.");
      return; // Year not found, nothing to remove
    }

    // Assuming removeYear expects the name (or ID if the service uses that)
    await _yearService.removeYear(yearName); // Pass the name string
    // Update state immutably (sorting is maintained)
    state = state.where((y) => y.name != yearName).toList();
  }
}

// StateNotifierProvider definition
final yearsProvider = StateNotifierProvider<YearsNotifier, List<Year>>((ref) {
  // Read the YearService instance from its provider
  final yearService = ref.watch(yearServiceProvider);
  return YearsNotifier(yearService);
});
