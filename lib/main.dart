import 'package:flutter/material.dart';

import 'navigation/app_shell.dart';
import 'playback/playback_controller.dart';
import 'theme.dart';

void main() => runApp(const RadioApp());

/// Root of the app.
///
/// Holds the single [PlaybackController] and opens on the navigation shell,
/// which starts at the Radio screen.
class RadioApp extends StatefulWidget {
  const RadioApp({super.key});

  @override
  State<RadioApp> createState() => _RadioAppState();
}

class _RadioAppState extends State<RadioApp> {
  final PlaybackController _controller = PlaybackController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Over',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AppShell(controller: _controller),
    );
  }
}