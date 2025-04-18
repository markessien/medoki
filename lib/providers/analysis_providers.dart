import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for transient analysis status messages, accessible globally
final analysisStatusProvider = StateProvider<String>((ref) => 'Ready');

// Provider to hold the path to the generated analysis HTML file
final analysisHtmlPathProvider = StateProvider<String?>((ref) => null);

// Provider to trigger a refresh of the analysis view
final analysisRefreshTriggerProvider = StateProvider<int>((ref) => 0);

// Add other analysis-related providers here in the future if needed.
