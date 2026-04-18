import 'package:flutter/material.dart';

class AddCardDialog extends StatefulWidget {
  final String side1Label;
  final String side2Label;

  const AddCardDialog({
    this.side1Label = 'Front',
    this.side2Label = 'Back',
    super.key,
  });

  @override
  State<AddCardDialog> createState() => _AddCardDialogState();
}

class _AddCardDialogState extends State<AddCardDialog> {
  final _side1Controller = TextEditingController();
  final _side2Controller = TextEditingController();

  @override
  void dispose() {
    _side1Controller.dispose();
    _side2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Card'),
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
          child: const Text('Create'),
        ),
      ],
    );
  }
}
