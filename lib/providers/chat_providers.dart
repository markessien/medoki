import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/analysis_chat_history_service.dart'; // Import the history service

// Provider for the expanded state of the Analysis chat
final analysisChatExpandedProvider = StateProvider<bool>((ref) => false);

// Provider for the expanded state of the Document chat
final documentChatExpandedProvider = StateProvider<bool>((ref) => false);

// Providers to track if the initial message has been added for each chat
final analysisChatInitialMessageProvider = StateProvider<bool>((ref) => false);
final documentChatInitialMessageProvider = StateProvider<bool>((ref) => false);

// Provider for the AnalysisChatHistoryService
final analysisChatHistoryServiceProvider = Provider<AnalysisChatHistoryService>(
  (ref) => AnalysisChatHistoryService(),
);

// Provider for the list of analysis chat messages
final analysisChatMessagesProvider =
    StateNotifierProvider<AnalysisChatMessagesNotifier, List<String>>((ref) {
      final historyService = ref.read(analysisChatHistoryServiceProvider);
      return AnalysisChatMessagesNotifier(historyService);
    });

// StateNotifier to manage the list of analysis chat messages and interact with the history service
class AnalysisChatMessagesNotifier extends StateNotifier<List<String>> {
  final AnalysisChatHistoryService _historyService;

  AnalysisChatMessagesNotifier(this._historyService) : super([]);

  // Load messages from history
  Future<void> loadMessages() async {
    state = await _historyService.loadHistory();
  }

  // Add a new message and save history
  void addMessage(String message) {
    state = [...state, message];
    _historyService.saveHistory(state);
  }

  // Clear all messages and history
  void clearMessages() {
    state = [];
    _historyService.saveHistory(state); // Save empty list to clear history
  }
}
