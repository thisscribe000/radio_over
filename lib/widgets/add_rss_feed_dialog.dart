import 'package:flutter/material.dart';
import '../theme.dart';

/// Minimalist modal dialog for adding an RSS podcast feed URL.
class AddRssFeedDialog extends StatefulWidget {
  const AddRssFeedDialog({super.key});

  /// Presents the [AddRssFeedDialog] and returns the entered feed URL or null if cancelled.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const AddRssFeedDialog(),
    );
  }

  @override
  State<AddRssFeedDialog> createState() => _AddRssFeedDialogState();
}

class _AddRssFeedDialogState extends State<AddRssFeedDialog> {
  late final TextEditingController _input;
  String? _error;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _submit() {
    final String url = _input.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter an RSS feed URL.');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _error = 'Please enter a valid http:// or https:// URL.');
      return;
    }
    Navigator.of(context).pop(url);
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.hairline),
      ),
      title: Row(
        children: [
          Icon(Icons.rss_feed, size: 22, color: colors.podcastAccent),
          const SizedBox(width: 8),
          Text(
            'Add RSS Podcast',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colors.ink,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter any podcast RSS feed URL to subscribe and stream episodes directly.',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('rss-add-input'),
              controller: _input,
              keyboardType: TextInputType.url,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'RSS feed URL *',
                hintText: 'https://example.com/podcast.xml',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: colors.accent, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('rss-add-cancel'),
          onPressed: _cancel,
          child: Text('CANCEL', style: TextStyle(color: colors.muted)),
        ),
        FilledButton(
          key: const ValueKey('rss-add-submit'),
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: colors.podcastAccent,
            foregroundColor: Colors.white,
          ),
          child: const Text('ADD'),
        ),
      ],
    );
  }
}
