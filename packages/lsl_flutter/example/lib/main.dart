// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lsl_flutter/lsl_flutter.dart';

void main() => runApp(const LslExample());

class LslExample extends StatefulWidget {
  const LslExample({super.key});

  @override
  State<LslExample> createState() => _LslExampleState();
}

class _LslExampleState extends State<LslExample> {
  Outlet? _outlet;
  LslMulticastLock? _multicastLock;
  String? _error;
  int _sent = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    LslMulticastLock? lock;
    try {
      lock = await LslMulticastLock.acquire();
      if (!mounted) {
        await lock.release();
        return;
      }
      final info = StreamInfo(
        name: 'Dart markers',
        type: 'Markers',
        channelCount: 1,
        channelFormat: ChannelFormat.string,
        sourceId: 'lsl-flutter-example',
      );
      try {
        _outlet = Outlet(streamInfo: info);
      } finally {
        info.destroy();
      }
      _multicastLock = lock;
      setState(() {});
    } catch (_) {
      await lock?.release();
      if (mounted) setState(() => _error = 'Could not start LSL.');
    }
  }

  @override
  void dispose() {
    _outlet?.destroy();
    unawaited(_multicastLock?.release());
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
            if (_error case final error?) Text(error),
            ElevatedButton(
              onPressed: _outlet == null
                  ? null
                  : () {
                      _outlet!.pushString('marker-${_sent + 1}');
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
