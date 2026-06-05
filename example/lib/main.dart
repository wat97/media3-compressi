import 'package:flutter/material.dart';
import 'package:vidsqueeze/vidsqueeze.dart';

void main() {
  runApp(const VidsqueezeExampleApp());
}

class VidsqueezeExampleApp extends StatelessWidget {
  const VidsqueezeExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('vidsqueeze example')),
        body: StreamBuilder<CompressionState>(
          stream: Vidsqueeze.instance.states(),
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Flutter plugin scaffold is ready.'),
                  const SizedBox(height: 12),
                  const Text('Current state stream preview:'),
                  const SizedBox(height: 8),
                  Text(snapshot.data?.phase.value ?? 'idle'),
                  const SizedBox(height: 24),
                  const Text('Use internal Android sample-app for real device validation during this phase.'),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

