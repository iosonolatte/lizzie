import 'package:flutter/material.dart';

/// Dialog for viewing and editing a comment on the current board position.
class CommentDialog extends StatefulWidget {
  final String initialComment;
  final ValueChanged<String> onSave;

  const CommentDialog({
    super.key,
    required this.initialComment,
    required this.onSave,
  });

  @override
  State<CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<CommentDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Comment'),
      content: TextField(
        controller: _controller,
        maxLines: 5,
        minLines: 3,
        decoration: const InputDecoration(
          hintText: 'Enter comment for this position...',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.newline,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_controller.text);
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
