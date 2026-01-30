import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class BleCameraControls extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const BleCameraControls({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("BLE Camera Controls (Beta)"),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => viewModel.triggerPhoto(),
              icon: const Icon(Icons.camera_alt),
              label: const Text("Take Photo"),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () => viewModel.startVideo(),
              icon: const Icon(Icons.videocam),
              label: const Text("Start Video"),
            ),
          ],
        ),
      ],
    );
  }
}
