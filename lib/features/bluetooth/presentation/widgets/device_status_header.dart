import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class DeviceStatusHeader extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const DeviceStatusHeader({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            Text(
              "Connected to ${viewModel.connectedDevice?.name ?? 'Unknown'}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (viewModel.batteryLevel != null)
              Row(
                children: [
                  Icon(
                    viewModel.batteryLevel! > 20
                        ? Icons.battery_full
                        : Icons.battery_alert,
                    color: viewModel.batteryLevel! > 20
                        ? Colors.green
                        : Colors.red,
                  ),
                  Text(
                    "${viewModel.batteryLevel}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            if (viewModel.heartRate != null && viewModel.heartRate! > 0)
              Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.favorite, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    "${viewModel.heartRate} BPM",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
