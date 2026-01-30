import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class AudioControls extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const AudioControls({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Audio Controls"),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => viewModel.toggleAudio(),
          style: ElevatedButton.styleFrom(
            backgroundColor: viewModel.isAudioEnabled
                ? Colors.red
                : Colors.green,
            foregroundColor: Colors.white,
          ),
          icon: Icon(
            viewModel.isAudioEnabled ? Icons.stop : Icons.mic,
          ),
          label: Text(
            viewModel.isAudioEnabled
                ? "Stop Audio Stream"
                : "Start Audio Stream",
          ),
        ),
      ],
    );
  }
}
