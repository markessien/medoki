import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'document_chat_widget.dart'; // Import the chat widget

// Placeholder provider for analysis settings/status (replace later)
final analysisStatusProvider = StateProvider<String>(
  (ref) => 'Ready for analysis.',
);

class AnalysisSidebar extends ConsumerWidget {
  const AnalysisSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(analysisStatusProvider);

    // Use Stack for layering floating chat widget
    return Container(
      width: 350, // Consistent width
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        border: Border(
          left: BorderSide(color: Colors.blueGrey[200]!, width: 1.0),
        ),
      ),
      child: Stack(
        children: [
          // --- Main Scrollable Content ---
          Positioned.fill(
            bottom: 60, // Estimate chat widget height + padding
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Add padding here
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analysis Options',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(height: 20, thickness: 1),
                    // Placeholder for analysis controls/settings
                    const Text('Analysis settings will go here.'),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Trigger analysis generation
                        ref.read(analysisStatusProvider.notifier).state =
                            'Generating analysis...';
                        // Simulate analysis completion
                        Future.delayed(const Duration(seconds: 3), () {
                          ref.read(analysisStatusProvider.notifier).state =
                              'Analysis complete.';
                          // Update results provider (example)
                          // ref.read(analysisResultsProvider.notifier).state = 'Generated results...';
                        });
                      },
                      icon: const Icon(Icons.assessment),
                      label: const Text('Generate Analysis'),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Status:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(status),
                    // Add more widgets as needed for analysis options
                  ],
                ),
              ),
            ),
          ),
          // --- Floating Chat Widget ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            // Pass null for filePath as context is different
            child: DocumentChatWidget(selectedFilePath: null),
          ),
          // --- End Floating Chat Widget ---
        ],
      ),
    );
  }
}
