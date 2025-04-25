import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart'; // Import the new chat providers
import '../providers/analysis_providers.dart';
import '../services/ai_service.dart';

// This widget will handle the chat functionality specifically for the Analysis tab.
// It will not be tied to a specific document like DocumentChatWidget.

class AnalysisChatWidget extends ConsumerStatefulWidget {
  const AnalysisChatWidget({super.key});

  @override
  ConsumerState<AnalysisChatWidget> createState() => _AnalysisChatWidgetState();
}

class _AnalysisChatWidgetState extends ConsumerState<AnalysisChatWidget> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  // Removed _messages local state
  bool _isLoading = false; // Local state for loading
  // Removed _isExpanded and _hasInitialMessage local state

  @override
  void initState() {
    super.initState();
    // Load messages from history when the widget initializes
    ref.read(analysisChatMessagesProvider.notifier).loadMessages();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Method to toggle the expanded state using the provider
  void _toggleExpanded(WidgetRef ref) {
    final isExpanded = ref.read(analysisChatExpandedProvider.notifier).state;
    ref.read(analysisChatExpandedProvider.notifier).state = !isExpanded;

    // Add initial message if expanding and it hasn't been added yet
    if (!isExpanded && !ref.read(analysisChatInitialMessageProvider)) {
      ref
          .read(analysisChatMessagesProvider.notifier)
          .addMessage('AI: Hi, what can I help you with?');
      ref.read(analysisChatInitialMessageProvider.notifier).state = true;
      // Scroll to the new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // Session management variables
  DateTime? _sessionStartTime;

  // Enhanced sendMessage for analysis context with Health Analysis Document
  Future<void> _sendMessage(WidgetRef ref) async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    // Session management: expire session after 1 hour
    final now = DateTime.now();
    if (_sessionStartTime == null ||
        now.difference(_sessionStartTime!).inMinutes >= 60) {
      // Expire session: clear chat history and reset session start time
      ref.read(analysisChatMessagesProvider.notifier).clearMessages();
      ref.read(analysisChatInitialMessageProvider.notifier).state = false;
      _sessionStartTime = now;
    }

    // If session just started, set the start time
    _sessionStartTime ??= now;

    // Add user message to the provider
    ref.read(analysisChatMessagesProvider.notifier).addMessage('You: $message');

    setState(() {
      _isLoading = true;
      // Expand chat when a message is sent using the provider
      ref.read(analysisChatExpandedProvider.notifier).state = true;
      if (!ref.read(analysisChatInitialMessageProvider)) {
        // Add initial message if sending the first message
        ref
            .read(analysisChatMessagesProvider.notifier)
            .addMessage('AI: Hi, what can I help you with?');
        ref.read(analysisChatInitialMessageProvider.notifier).state = true;
      }
    });
    _chatController.clear();

    // Read the Health Analysis Document as context
    String? analysisHtmlPath = ref.read(analysisHtmlPathProvider);
    String healthAnalysisDocument = '';
    if (analysisHtmlPath != null && analysisHtmlPath.isNotEmpty) {
      try {
        final file = File(analysisHtmlPath);
        if (await file.exists()) {
          healthAnalysisDocument = await file.readAsString();
        } else {
          healthAnalysisDocument =
              '[Health Analysis Document not found at $analysisHtmlPath]';
        }
      } catch (e) {
        healthAnalysisDocument = '[Error reading Health Analysis Document: $e]';
      }
    } else {
      healthAnalysisDocument = '[No Health Analysis Document path available]';
    }

    // Call the AI service with the message and context
    final aiService = ref.read(aiServiceProvider);
    final aiReply = await aiService.sendAnalysisChatMessage(
      userMessage: message,
      healthAnalysisDocument: healthAnalysisDocument,
    );

    // Add AI response to the provider
    ref.read(analysisChatMessagesProvider.notifier).addMessage('AI: $aiReply');

    setState(() {
      _isLoading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch the expanded state from the provider
    final isExpanded = ref.watch(analysisChatExpandedProvider);
    // Watch the messages from the provider
    final messages = ref.watch(analysisChatMessagesProvider);
    final isLoading = _isLoading;

    return AnimatedContainer(
      // Use AnimatedContainer to animate height changes
      duration: const Duration(milliseconds: 300),
      height:
          isExpanded
              ? 300.0
              : 60.0, // Define heights for expanded/collapsed states
      curve: Curves.easeInOut,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border(
            top: BorderSide(color: Colors.grey.shade400, width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 0,
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Column takes minimum space
          children: [
            if (isExpanded) // Conditionally render chat history when expanded
              Expanded(
                child: Container(
                  // White, bordered container for chat history
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300, width: 1.0),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  padding: const EdgeInsets.all(8.0),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isUserMessage = message.startsWith('You: ');
                      final messageText =
                          isUserMessage
                              ? message.substring(5)
                              : message.substring(
                                4,
                              ); // Remove "You: " or "AI: " prefix

                      return Align(
                        // Align message based on sender
                        alignment:
                            isUserMessage
                                ? Alignment
                                    .centerRight // User messages on the right
                                : Alignment
                                    .centerLeft, // App messages on the left
                        child: Container(
                          // Container for individual message bubble (optional styling)
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          decoration: BoxDecoration(
                            color:
                                isUserMessage
                                    ? Colors.blue[100]
                                    : Colors.green[100],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Row(
                            // Row for icon and text
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isUserMessage) // App icon on the left
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Icon(
                                    Icons.computer,
                                    size: 20,
                                    color: Colors.green[800],
                                  ),
                                ),
                              Flexible(
                                // Flexible to allow text wrapping
                                child: SelectableText(
                                  messageText,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                              if (isUserMessage) // User icon on the right
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.blue[800],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (isExpanded && messages.isNotEmpty)
              const Divider(), // Conditionally render divider
            Row(
              // Input row
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    decoration: InputDecoration(
                      hintText:
                          'chat about the analysis report', // Hint text for analysis chat
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted:
                        !isLoading
                            ? (_) => _sendMessage(ref)
                            : null, // Pass ref to sendMessage
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  // Send button
                  icon:
                      isLoading
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.send),
                  onPressed:
                      !_isLoading
                          ? () => _sendMessage(ref)
                          : null, // Pass ref to sendMessage
                  tooltip: 'Send message',
                  color: Theme.of(context).colorScheme.primary,
                  disabledColor: Colors.grey,
                ),
                // Toggle button
                IconButton(
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed:
                      () => _toggleExpanded(ref), // Pass ref to toggleExpanded
                  tooltip: isExpanded ? 'Collapse chat' : 'Expand chat',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
