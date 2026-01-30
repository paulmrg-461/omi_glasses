import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class ServiceListDisplay extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const ServiceListDisplay({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text("Connection Verified via Service Discovery:"),
        if (viewModel.connectedDeviceServices.isNotEmpty)
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
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
              const Text(
                "No services found (or discovery pending)",
              ),
              TextButton.icon(
                onPressed: () => viewModel.retryServiceDiscovery(),
                icon: const Icon(Icons.refresh),
                label: const Text("Retry Discovery"),
              ),
            ],
          ),
      ],
    );
  }
}
