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
          if (viewModel.connectedDevice != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    "Connected to ${viewModel.connectedDevice!.name}",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  const Text("Connection Verified via Service Discovery:"),
                  const SizedBox(height: 8),
                  if (viewModel.connectedDeviceServices.isNotEmpty)
                    Container(
                      height: 150,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: viewModel.connectedDeviceServices.length,
                        itemBuilder: (context, index) {
                          return Text(
                            "Service: ${viewModel.connectedDeviceServices[index]}",
                            style: const TextStyle(fontSize: 12),
                          );
                        },
                      ),
                    )
                  else
                    Column(
                      children: [
                        const Text("No services found (or discovery pending)"),
                        TextButton.icon(
                          onPressed: () => viewModel.retryServiceDiscovery(),
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry Discovery"),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.amber.shade100,
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Note: Camera streaming requires Wi-Fi. BLE is ready for commands.",
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      viewModel.disconnect();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                    ),
                    child: const Text("Disconnect"),
                  ),
                ],
              ),
            );
          }

          final sortedDevices = List.of(viewModel.devices)
            ..sort((a, b) => b.rssi.compareTo(a.rssi));

          return Stack(
            children: [
              Column(
                children: [
                  if (viewModel.errorMessage != null)
                    Container(
                      color: Colors.red.shade100,
                      padding: const EdgeInsets.all(8.0),
                      width: double.infinity,
                      child: Text(
                        viewModel.errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ElevatedButton(
                      onPressed: viewModel.isScanning || viewModel.isConnecting
                          ? (viewModel.isScanning ? viewModel.stopScan : null)
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
              ),
              if (viewModel.isConnecting)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Connecting... Please wait.",
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          "(This may take up to 30 seconds)",
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
