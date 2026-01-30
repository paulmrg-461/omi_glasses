import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/bluetooth_viewmodel.dart';
import '../widgets/connected_device_view.dart';
import '../widgets/scan_results_list.dart';
import '../widgets/loading_overlay.dart';

class BluetoothScanPage extends StatelessWidget {
  const BluetoothScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OMI Glasses')),
      body: Consumer<BluetoothViewModel>(
        builder: (context, viewModel, child) {
          return Stack(
            children: [
              // Main Content
              if (viewModel.connectedDevice != null)
                ConnectedDeviceView(viewModel: viewModel)
              else
                ScanResultsList(viewModel: viewModel),

              // Loading Overlays
              if (viewModel.isConnecting)
                const LoadingOverlay(
                  message: "Connecting... Please wait.",
                  subMessage: "(This may take up to 30 seconds)",
                ),

              if (viewModel.isSettingUpWifi)
                const LoadingOverlay(
                  message: "Sending Wi-Fi Credentials...",
                  subMessage: "Please check logs if this hangs.",
                ),
            ],
          );
        },
      ),
    );
  }
}
