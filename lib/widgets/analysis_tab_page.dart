import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Placeholder provider for analysis results (replace with actual logic later)
final analysisResultsProvider = StateProvider<String>(
  (ref) => 'Analysis results will appear here...',
);

class AnalysisTabPage extends ConsumerWidget {
  const AnalysisTabPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisResults = ref.watch(analysisResultsProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Medical Analysis',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          // Placeholder for analysis generation controls if needed
          // ElevatedButton.icon(
          //   onPressed: () {
          //     // TODO: Trigger analysis generation
          //   },
          //   icon: const Icon(Icons.assessment),
          //   label: const Text('Generate Analysis'),
          // ),
          // const SizedBox(height: 20),
          const Text(
            'Results:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              // Make results scrollable
              child: Text(analysisResults),
            ),
          ),
        ],
      ),
    );
  }
}
