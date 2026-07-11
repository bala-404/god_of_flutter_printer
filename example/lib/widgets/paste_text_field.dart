import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text field with a paste-from-clipboard action.
class PasteTextField extends StatelessWidget {
  const PasteTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  Future<void> _paste(BuildContext context) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    controller.text = text;
    onChanged?.call(text);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pasted from clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        suffixIcon: IconButton(
          onPressed: () => _paste(context),
          icon: const Icon(Icons.content_paste),
          tooltip: 'Paste',
        ),
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
