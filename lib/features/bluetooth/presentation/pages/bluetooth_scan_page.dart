import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class BluetoothScanPage extends StatelessWidget {
  const BluetoothScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to OMI Glasses')),
      body: Consumer<BluetoothViewModel>(
        builder: (context, viewModel, child) {
          final sortedDevices = List.of(viewModel.devices)
            ..sort((a, b) => b.rssi.compareTo(a.rssi));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: viewModel.isScanning
                      ? viewModel.stopScan
                      : viewModel.startScan,
                  child: Text(
                    viewModel.isScanning ? 'Stop Scan' : 'Start Scan',
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: sortedDevices.length,
                  itemBuilder: (context, index) {
                    final device = sortedDevices[index];
                    return ListTile(
                      title: Text(device.name),
                      subtitle: Text(device.id),
                      trailing: ElevatedButton(
                        onPressed: () {
                          viewModel.connect(device.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Connecting to ${device.name}...'),
                            ),
                          );
                        },
                        child: const Text("Connect"),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
