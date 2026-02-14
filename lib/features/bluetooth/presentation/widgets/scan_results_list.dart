import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class ScanResultsList extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const ScanResultsList({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (viewModel.errorMessage != null)
          Container(
            color: Colors.red.shade100,
            padding: const EdgeInsets.all(8.0),
            width: double.infinity,
            child: Column(
              children: [
                Text(
                  viewModel.errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                  textAlign: TextAlign.center,
                ),
                if (viewModel.errorMessage!.contains(
                  "Bluetooth está desactivado",
                ))
                  TextButton(
                    onPressed: () => viewModel.enableBluetooth(),
                    child: const Text("Activar Bluetooth"),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: viewModel.isScanning || viewModel.isConnecting
                ? (viewModel.isScanning ? viewModel.stopScan : null)
                : viewModel.startScan,
            child: Text(viewModel.isScanning ? 'Stop Scan' : 'Start Scan'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: viewModel.devices.length,
            itemBuilder: (context, index) {
              final sortedDevices = List.of(viewModel.devices)
                ..sort((a, b) => b.rssi.compareTo(a.rssi));
              final device = sortedDevices[index];
              final isConnected = viewModel.connectedDevices.any((d) => d.id == device.id);
              return ListTile(
                title: Text(device.name),
                subtitle: Text(device.id),
                trailing: isConnected
                    ? const Text("Connected", style: TextStyle(color: Colors.green))
                    : ElevatedButton(
                        onPressed: viewModel.isConnecting
                            ? null
                            : () => viewModel.connect(device.id),
                        child: const Text("Connect"),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}
