import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class StatusMessageDisplay extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const StatusMessageDisplay({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (viewModel.statusMessage != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              children: [
                const Icon(Icons.info, color: Colors.blue),
                const SizedBox(height: 8),
                Text(
                  viewModel.statusMessage!,
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        if (viewModel.errorMessage != null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                ),
                const SizedBox(height: 8),
                Text(
                  viewModel.errorMessage!,
                  style: TextStyle(
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
