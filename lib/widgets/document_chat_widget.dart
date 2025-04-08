import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Placeholder provider for chat messages (replace with actual logic later)
final chatMessagesProvider = StateProvider<List<String>>((ref) => []);
// Placeholder provider for chat loading state
final chatLoadingProvider = StateProvider<bool>((ref) => false);

class DocumentChatWidget extends ConsumerStatefulWidget {
  final String? selectedFilePath; // Pass the selected file path

  const DocumentChatWidget({super.key, required this.selectedFilePath});

  @override
  ConsumerState<DocumentChatWidget> createState() => _DocumentChatWidgetState();
}

class _DocumentChatWidgetState extends ConsumerState<DocumentChatWidget> {
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController =
      ScrollController(); // To scroll chat

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty || widget.selectedFilePath == null) return;

    final currentMessages = ref.read(chatMessagesProvider);
    ref.read(chatMessagesProvider.notifier).state = [
      ...currentMessages,
      'You: $message',
    ];
    _chatController.clear();
    ref.read(chatLoadingProvider.notifier).state = true;

    // Simulate AI response (replace with actual API call)
    await Future.delayed(const Duration(seconds: 2));
    final aiResponse =
        'AI: Responding about ${widget.selectedFilePath} to "$message"';
    final updatedMessages = ref.read(chatMessagesProvider);
    ref.read(chatMessagesProvider.notifier).state = [
      ...updatedMessages,
      aiResponse,
    ];
    ref.read(chatLoadingProvider.notifier).state = false;

    // Scroll to bottom after sending/receiving
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
    final messages = ref.watch(chatMessagesProvider);
    final isLoading = ref.watch(chatLoadingProvider);

    // Disable input if no file is selected
    final bool enableInput = widget.selectedFilePath != null;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        // Use a slightly more distinct background color
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          // Make the top border slightly darker
          top: BorderSide(color: Colors.grey.shade400, width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 5,
            offset: const Offset(0, -2), // changes position of shadow
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Take minimum space needed
        children: [
          // --- Chat History (Optional, uncomment to show) ---
          // if (messages.isNotEmpty)
          //   SizedBox(
          //     height: 100, // Limit height
          //     child: ListView.builder(
          //       controller: _scrollController,
          //       itemCount: messages.length,
          //       itemBuilder: (context, index) => Padding(
          //         padding: const EdgeInsets.symmetric(vertical: 2.0),
          //         child: Text(messages[index], style: const TextStyle(fontSize: 12)),
          //       ),
          //     ),
          //   ),
          // if (messages.isNotEmpty) const Divider(),
          // --- Chat Input Row ---
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  enabled: enableInput,
                  decoration: InputDecoration(
                    hintText:
                        enableInput
                            ? 'Ask about the document...'
                            : 'Select a file to chat',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20.0),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10.0,
                    ),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14),
                  onSubmitted:
                      enableInput && !isLoading ? (_) => _sendMessage() : null,
                ),
              ),
              const SizedBox(width: 8.0),
              IconButton(
                icon:
                    isLoading
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.send),
                onPressed: enableInput && !isLoading ? _sendMessage : null,
                tooltip: 'Send message',
                color: Theme.of(context).colorScheme.primary,
                disabledColor: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
