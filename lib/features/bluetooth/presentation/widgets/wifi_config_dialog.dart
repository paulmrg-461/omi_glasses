import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class WifiConfigDialog extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const WifiConfigDialog({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final ssidController = TextEditingController();
    final passwordController = TextEditingController();

    return AlertDialog(
      title: const Text("Configure Wi-Fi"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Enter your Wi-Fi credentials to enable camera streaming.",
          ),
          const SizedBox(height: 16),
          TextField(
            controller: ssidController,
            decoration: const InputDecoration(
              labelText: "SSID (Network Name)",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            decoration: const InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(),
            ),
            obscureText: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            viewModel.setupWifi(ssidController.text, passwordController.text);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Sending credentials... Watch for IP."),
              ),
            );
          },
          child: const Text("Connect"),
        ),
      ],
    );
  }
}
