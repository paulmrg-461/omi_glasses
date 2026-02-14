import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class ConnectedDevicesList extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const ConnectedDevicesList({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Colors.green.shade50,
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Connected Devices (Tap to Control)",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: viewModel.connectedDevices.length,
              itemBuilder: (context, index) {
                final device = viewModel.connectedDevices[index];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => viewModel.selectDevice(device),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bluetooth_connected, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(device.name.isNotEmpty ? device.name : "Unknown"),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => viewModel.disconnect(device.id),
                            tooltip: "Disconnect",
                          )
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
