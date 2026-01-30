import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';
import '../pages/camera_page.dart';
import 'wifi_config_dialog.dart';

class CameraWifiSetup extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const CameraWifiSetup({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.cameraIp != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green.shade100,
            child: Row(
              children: [
                const Icon(Icons.wifi, color: Colors.green),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Glasses Connected! IP: ${viewModel.cameraIp}",
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraPage(ipAddress: viewModel.cameraIp!),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
            icon: const Icon(Icons.videocam),
            label: const Text("OPEN LIVE CAMERA"),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.amber.shade100,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Camera requires Wi-Fi. Setup below.",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => WifiConfigDialog(viewModel: viewModel),
              );
            },
            icon: const Icon(Icons.wifi_tethering),
            label: const Text("Setup Wi-Fi for Camera"),
          ),
        ],
      );
    }
  }
}
