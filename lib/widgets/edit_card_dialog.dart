import 'package:flutter/material.dart';

class EditCardDialog extends StatefulWidget {
  final String initialQuestion;
  final String initialAnswer;
  final String side1Label;
  final String side2Label;

  const EditCardDialog({
    required this.initialQuestion,
    required this.initialAnswer,
    this.side1Label = 'Front',
    this.side2Label = 'Back',
    super.key,
  });

  @override
  State<EditCardDialog> createState() => _EditCardDialogState();
}

class _EditCardDialogState extends State<EditCardDialog> {
  late TextEditingController _side1Controller;
  late TextEditingController _side2Controller;

  @override
  void initState() {
    super.initState();
    _side1Controller = TextEditingController(text: widget.initialQuestion);
    _side2Controller = TextEditingController(text: widget.initialAnswer);
  }

  @override
  void dispose() {
    _side1Controller.dispose();
    _side2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _side1Controller,
            decoration: InputDecoration(labelText: widget.side1Label),
            autofocus: true,
          ),
          TextField(
            controller: _side2Controller,
            decoration: InputDecoration(labelText: widget.side2Label),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, {
            'question': _side1Controller.text,
            'answer': _side2Controller.text,
          }),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
