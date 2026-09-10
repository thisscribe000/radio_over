import 'package:flutter/material.dart';
import '../models/station.dart';
import '../playback/playback_controller.dart';
import '../theme.dart';

/// Minimalist modal dialog allowing listeners to add a custom Icecast/Shoutcast/HLS stream URL.
class AddCustomStationDialog extends StatefulWidget {
  const AddCustomStationDialog({
    super.key,
    required this.controller,
    this.onStationAdded,
  });

  final PlaybackController controller;
  final void Function(RadioStation station)? onStationAdded;

  static Future<void> show(
    BuildContext context, {
    required PlaybackController controller,
    void Function(RadioStation station)? onStationAdded,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => AddCustomStationDialog(
        controller: controller,
        onStationAdded: onStationAdded,
      ),
    );
  }

  @override
  State<AddCustomStationDialog> createState() => _AddCustomStationDialogState();
}

class _AddCustomStationDialogState extends State<AddCustomStationDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _save({bool playImmediately = false}) {
    final String name = _nameController.text.trim();
    final String url = _urlController.text.trim();
    final String category = _categoryController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a station name.');
      return;
    }
    if (url.isEmpty || (!url.startsWith('http://') && !url.startsWith('https://'))) {
      setState(() => _error = 'Please enter a valid http:// or https:// stream URL.');
      return;
    }

    final RadioStation station = RadioStation(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      category: category.isNotEmpty ? category : 'Custom',
      program: 'CUSTOM STREAM',
      streamUrl: url,
      isOnline: true,
    );

    widget.controller.toggleFavouriteStation(station.stationId, details: station);
    widget.onStationAdded?.call(station);

    if (playImmediately) {
      widget.controller.playRadioStation(station);
    }

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
          Icon(Icons.radio, size: 22, color: colors.accent),
          const SizedBox(width: 8),
          Text(
            'Add Custom Radio',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.ink),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter direct MP3, AAC, or HLS stream URL.',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('custom-station-name-field'),
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Station Name *',
                hintText: 'e.g. My Jazz Radio',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('custom-station-url-field'),
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Stream URL *',
                hintText: 'https://stream.example.com/live.mp3',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('custom-station-cat-field'),
              controller: _categoryController,
              decoration: InputDecoration(
                labelText: 'Genre / Category (Optional)',
                hintText: 'e.g. Electronic, Ambient',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.redAccent),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CANCEL', style: TextStyle(color: colors.muted)),
        ),
        TextButton(
          key: const ValueKey('custom-station-save-btn'),
          onPressed: () => _save(playImmediately: false),
          child: Text('SAVE', style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton(
          key: const ValueKey('custom-station-play-btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.background,
          ),
          onPressed: () => _save(playImmediately: true),
          child: const Text('SAVE & PLAY', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
