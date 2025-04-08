import 'package:flutter/material.dart';

class RecommendationsConfirmationDialog extends StatefulWidget {
  const RecommendationsConfirmationDialog({super.key});

  @override
  State<RecommendationsConfirmationDialog> createState() =>
      _RecommendationsConfirmationDialogState();
}

class _RecommendationsConfirmationDialogState
    extends State<RecommendationsConfirmationDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _isConfirmEnabled = false;
  final String _confirmationText = "I am sure";

  @override
  void initState() {
    super.initState();
    _controller.addListener(_validateInput);
  }

  @override
  void dispose() {
    _controller.removeListener(_validateInput);
    _controller.dispose();
    super.dispose();
  }

  void _validateInput() {
    setState(() {
      _isConfirmEnabled = _controller.text == _confirmationText;
    });
  }

  void _confirm() {
    if (_isConfirmEnabled) {
      Navigator.of(context).pop(true); // Return true to indicate confirmation
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Recommendations Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min, // Prevent excessive vertical space
        children: [
          Text(
            'This action may incur costs or use API credits.\nPlease type "$_confirmationText" below to confirm.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Type "$_confirmationText" here',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _confirm(), // Allow confirming with Enter key
          ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(false), // Return false
        ),
        TextButton(
          // Use TextButton for consistency, style it if needed
          onPressed: _isConfirmEnabled ? _confirm : null, // Enable/disable
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
