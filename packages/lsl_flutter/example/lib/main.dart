// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'package:flutter/material.dart';
import 'package:lsl_flutter/lsl_flutter.dart';

void main() => runApp(const LslExample());

class LslExample extends StatefulWidget {
  const LslExample({super.key});

  @override
  State<LslExample> createState() => _LslExampleState();
}

class _LslExampleState extends State<LslExample> {
  late final Outlet _outlet;
  int _sent = 0;

  @override
  void initState() {
    super.initState();
    final info = StreamInfo(
      name: 'Dart markers',
      type: 'Markers',
      channelCount: 1,
      channelFormat: ChannelFormat.string,
      sourceId: 'lsl-flutter-example',
    );
    _outlet = Outlet(streamInfo: info);
    info.destroy();
  }

  @override
  void dispose() {
    _outlet.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Lab Streaming Layer')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('liblsl $libraryVersion'),
            Text('Markers sent: $_sent'),
            ElevatedButton(
              onPressed: () {
                _outlet.pushString('marker-${_sent + 1}');
                setState(() => _sent++);
              },
              child: const Text('Send marker'),
            ),
          ],
        ),
      ),
    ),
  );
}
