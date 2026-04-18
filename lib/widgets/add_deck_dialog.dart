import 'package:flutter/material.dart';

class AddDeckDialog extends StatefulWidget {
  const AddDeckDialog({super.key});

  @override
  State<AddDeckDialog> createState() => _AddDeckDialogState();
}

class _AddDeckDialogState extends State<AddDeckDialog> {
  final _nameController = TextEditingController();
  final _side1Controller = TextEditingController();
  final _side2Controller = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _side1Controller.dispose();
    _side2Controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty) return;
    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'side1Label': _side1Controller.text.trim().isEmpty
          ? 'Front'
          : _side1Controller.text.trim(),
      'side2Label': _side2Controller.text.trim().isEmpty
          ? 'Back'
          : _side2Controller.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Deck'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Deck Name',
              hintText: 'Enter deck name',
            ),
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _side1Controller,
            decoration: const InputDecoration(
              labelText: 'Side 1 Name',
              hintText: 'Front',
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          TextField(
            controller: _side2Controller,
            decoration: const InputDecoration(
              labelText: 'Side 2 Name',
              hintText: 'Back',
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}
