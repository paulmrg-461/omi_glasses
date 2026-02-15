import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';
import 'device_status_header.dart';
import 'camera_wifi_setup.dart';
import 'ble_camera_controls.dart';
import 'audio_controls.dart';
import 'image_display.dart';
import 'status_message_display.dart';
import 'service_list_display.dart';

class ConnectedDeviceView extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const ConnectedDeviceView({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DeviceStatusHeader(viewModel: viewModel),
          const SizedBox(height: 16),
          CameraWifiSetup(viewModel: viewModel),
          const SizedBox(height: 16),
          const Divider(),
          BleCameraControls(viewModel: viewModel),
          const SizedBox(height: 16),
          const Divider(),
          AudioControls(viewModel: viewModel),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => viewModel.summarizeNow(),
            icon: const Icon(Icons.save),
            label: const Text("Guardar resumen ahora"),
          ),
          const SizedBox(height: 8),
          ImageDisplay(viewModel: viewModel),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => viewModel.clearSelectedDevice(),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Back to List"),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => viewModel.disconnect(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                ),
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text("Disconnect"),
              ),
            ],
          ),
          const Divider(),
          StatusMessageDisplay(viewModel: viewModel),
          ServiceListDisplay(viewModel: viewModel),
        ],
      ),
    );
  }
}
