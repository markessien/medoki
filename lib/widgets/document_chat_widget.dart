import 'dart:io'; // Import for File operations
import 'package:flutter/material.dart';
import 'dart:io'; // Import for File operations
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mediciapp/widgets/medical_records_page.dart'; // Import to access medicalRecordsProvider
import 'package:path/path.dart' as p; // Import path package
import '../providers/chat_providers.dart'; // Import the new chat providers
import '../services/ai_service.dart';

// Removed global providers, state will be managed locally

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
  List<String> _messages = []; // Local state for messages
  bool _isLoading = false; // Local state for loading
  // Removed _isExpanded and _hasInitialMessage local state

  @override
  void initState() {
    super.initState();
    // Clear chat if a file is already selected on initial build
    if (widget.selectedFilePath != null) {
      // Use ref to access the provider and clear state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(documentChatExpandedProvider.notifier).state = false;
        ref.read(documentChatInitialMessageProvider.notifier).state = false;
      });
      _clearChat(); // Clear local messages
    }
  }

  @override
  void didUpdateWidget(covariant DocumentChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Clear chat if the selected file path changes and reset initial message flag
    if (widget.selectedFilePath != oldWidget.selectedFilePath) {
      _clearChat(); // Clear local messages
      // Use ref to access the provider and reset state
      ref.read(documentChatExpandedProvider.notifier).state = false;
      ref.read(documentChatInitialMessageProvider.notifier).state = false;
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Moved _clearChat outside of _sendMessage
  void _clearChat() {
    setState(() {
      _messages = [];
      _isLoading = false;
      _chatController.clear(); // Also clear the input field
      // Expanded and initial message state are now managed by providers
    });
  }

  // Method to toggle the expanded state using the provider
  void _toggleExpanded(WidgetRef ref) {
    final isExpanded = ref.read(documentChatExpandedProvider.notifier).state;
    ref.read(documentChatExpandedProvider.notifier).state = !isExpanded;

    // Add initial message if expanding and it hasn't been added yet
    if (!isExpanded &&
        !ref.read(documentChatInitialMessageProvider) &&
        widget.selectedFilePath != null) {
      _messages.add(
        'AI: Hi, what can I help you with regarding this document?',
      );
      ref.read(documentChatInitialMessageProvider.notifier).state = true;
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

  // Removed duplicate _sendMessage definition start
  Future<void> _sendMessage(WidgetRef ref) async {
    final message = _chatController.text.trim();
    if (message.isEmpty || widget.selectedFilePath == null) return;

    // Update local state
    setState(() {
      _messages = [..._messages, 'You: $message'];
      _isLoading = true;
      // Expand chat when a message is sent using the provider
      ref.read(documentChatExpandedProvider.notifier).state = true;
      if (!ref.read(documentChatInitialMessageProvider)) {
        // Add initial message if sending the first message
        _messages.insert(
          0,
          'AI: Hi, what can I help you with regarding this document?',
        );
        ref.read(documentChatInitialMessageProvider.notifier).state = true;
      }
    });
    _chatController.clear();

    // --- Get context from the SELECTED .medoki.json file ---
    // Modified to get context ONLY from the selected file's medoki data
    String selectedMedokiContent =
        "Could not find or read the associated .medoki.json file for context."; // Default context
    try {
      // Construct the path to the corresponding .medoki.json file
      final originalFileDir = p.dirname(widget.selectedFilePath!);
      final originalFileName = p.basename(widget.selectedFilePath!);
      // Assuming .medoki.json files are in a 'data-files' subdirectory relative to the original
      // Adjust this logic if your file structure is different
      final dataFilesDir = p.join(originalFileDir, 'data-files');
      final medokiPath = p.join(dataFilesDir, '$originalFileName.medoki.json');
      final medokiFile = File(medokiPath);

      if (await medokiFile.exists()) {
        selectedMedokiContent = await medokiFile.readAsString();
      } else {
        selectedMedokiContent =
            "No .medoki.json file found at expected path: $medokiPath";
      }
    } catch (e) {
      print("Error reading selected medoki file for chat context: $e");
      // Keep the default error message
    }
    // ---------------------------------------------

    // Simulate AI response (replace with actual API call)
    // TODO: Replace this simulation with a real call to your AI service,
    // passing `message` and `selectedMedokiContent` as input.
    await Future.delayed(const Duration(seconds: 2)); // Simulate network delay
    final aiResponse =
        'AI: Responding to "$message" (Context: ${selectedMedokiContent.length} chars from ${p.basename(widget.selectedFilePath!)})'; // Example response

    // Update local state with AI response
    setState(() {
      _messages = [..._messages, aiResponse];
      _isLoading = false;
    });

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
    // Watch the expanded state from the provider
    final isExpanded = ref.watch(documentChatExpandedProvider);
    final messages = _messages; // Still using local messages for now
    final isLoading = _isLoading;

    // Disable input if no file is selected
    final bool enableInput = widget.selectedFilePath != null;

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
          // Use a slightly more distinct background color
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          mainAxisSize: MainAxisSize.min, // Column takes minimum space
          children: [
            // --- Chat History ---
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
                                ? Alignment.centerRight
                                : Alignment
                                    .centerLeft, // User on right, App on left
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
                              ? 'chat with your medical documents' // Changed hint text
                              : 'Select a file to chat',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white, // Changed background to white
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 10.0,
                      ),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted:
                        enableInput && !isLoading
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
                      enableInput && !_isLoading
                          ? () => _sendMessage(ref)
                          : null, // Use local state and pass ref
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
                      enableInput
                          ? () => _toggleExpanded(ref)
                          : null, // Disable toggle if no file selected and pass ref
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
