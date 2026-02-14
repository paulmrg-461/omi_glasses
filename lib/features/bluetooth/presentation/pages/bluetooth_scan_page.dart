import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../viewmodels/bluetooth_viewmodel.dart';
import '../widgets/connected_device_view.dart';
import '../widgets/scan_results_list.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/connected_devices_list.dart';

class BluetoothScanPage extends StatelessWidget {
  const BluetoothScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OMI Glasses'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider(
                    create: (_) => di.sl<SettingsBloc>()..add(LoadSettings()),
                    child: const SettingsPage(),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Consumer<BluetoothViewModel>(
        builder: (context, viewModel, child) {
          // If a device is explicitly selected, show its control view
          if (viewModel.connectedDevice != null) {
            return Stack(
              children: [
                ConnectedDeviceView(viewModel: viewModel),
                if (viewModel.isSettingUpWifi)
                  const LoadingOverlay(
                    message: "Sending Wi-Fi Credentials...",
                    subMessage: "Please check logs if this hangs.",
                  ),
              ],
            );
          }

          // Otherwise show the list of connected devices + scan results
          return Stack(
            children: [
              Column(
                children: [
                  if (viewModel.connectedDevices.isNotEmpty)
                    ConnectedDevicesList(viewModel: viewModel),
                  Expanded(child: ScanResultsList(viewModel: viewModel)),
                ],
              ),

              // Loading Overlays
              if (viewModel.isConnecting)
                const LoadingOverlay(
                  message: "Connecting... Please wait.",
                  subMessage: "(This may take up to 30 seconds)",
                ),
            ],
          );
        },
      ),
    );
  }
}
