import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/bluetooth_viewmodel.dart';
import 'camera_page.dart';

class BluetoothScanPage extends StatelessWidget {
  const BluetoothScanPage({super.key});

  void _showWifiDialog(BuildContext context, BluetoothViewModel viewModel) {
    final ssidController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to OMI Glasses')),
      body: Consumer<BluetoothViewModel>(
        builder: (context, viewModel, child) {
          // Show error dialog if error exists and not shown?
          // Since we cannot trigger dialogs here easily without PostFrameCallback and checking "seen" state,
          // We will rely on the inline error message AND the loading overlay.

          return Stack(
            children: [
              // Main Content
              if (viewModel.connectedDevice != null) ...[
                SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Connected to ${viewModel.connectedDevice!.name}",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),

                      // Status Message Display (Inline)
                      if (viewModel.statusMessage != null)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.info, color: Colors.blue),
                              const SizedBox(height: 8),
                              Text(
                                viewModel.statusMessage!,
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                      // Error Message Display (Inline)
                      if (viewModel.errorMessage != null)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                viewModel.errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

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
                            const Text(
                              "No services found (or discovery pending)",
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  viewModel.retryServiceDiscovery(),
                              icon: const Icon(Icons.refresh),
                              label: const Text("Retry Discovery"),
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),
                      if (viewModel.cameraIp != null) ...[
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
                                builder: (_) =>
                                    CameraPage(ipAddress: viewModel.cameraIp!),
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
                      ] else ...[
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
                          onPressed: () => _showWifiDialog(context, viewModel),
                          icon: const Icon(Icons.wifi_tethering),
                          label: const Text("Setup Wi-Fi for Camera"),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text("BLE Camera Controls (Beta)"),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => viewModel.triggerPhoto(),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text("Take Photo"),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: () => viewModel.startVideo(),
                              icon: const Icon(Icons.videocam),
                              label: const Text("Start Video"),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const Text("Audio Controls"),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => viewModel.toggleAudio(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: viewModel.isAudioEnabled
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            viewModel.isAudioEnabled ? Icons.stop : Icons.mic,
                          ),
                          label: Text(
                            viewModel.isAudioEnabled
                                ? "Stop Audio Stream"
                                : "Start Audio Stream",
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Status Indicator for Image Transfer
                        if (viewModel.imageTransferStatus != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              viewModel.imageTransferStatus!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        TextButton(
                          onPressed: () => viewModel.startImageListener(),
                          child: const Text("Restart Image Listener"),
                        ),
                        const SizedBox(height: 16),
                        // Image Display
                        Container(
                          height: 200,
                          width: double.infinity,
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: viewModel.lastImage != null
                              ? Image.memory(
                                  viewModel.lastImage!,
                                  gaplessPlayback: true,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Ignore error and show raw data info if needed, or placeholder
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons
                                                .image_not_supported, // Less alarming icon
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            "Partial Image Data",
                                            style: TextStyle(
                                              color: Colors.orange,
                                            ),
                                          ),
                                          Text(
                                            "${viewModel.lastImage?.length ?? 0} bytes",
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          ),
                                          if (viewModel.imageHeaderHex !=
                                              null) ...[
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: SelectableText(
                                                "Header: ${viewModel.imageHeaderHex}",
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontFamily: 'monospace',
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            if (viewModel.lastImage != null &&
                                                viewModel.lastImage!.length >
                                                    10)
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: SelectableText(
                                                  "Tail: ${viewModel.lastImage!.sublist(viewModel.lastImage!.length - 10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}",
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontFamily: 'monospace',
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                      Text("No Image Data"),
                                    ],
                                  ),
                                ),
                        ),
                      ],

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
                ),
              ] else ...[
                // Not Connected View
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
                        onPressed:
                            viewModel.isScanning || viewModel.isConnecting
                            ? (viewModel.isScanning ? viewModel.stopScan : null)
                            : viewModel.startScan,
                        child: Text(
                          viewModel.isScanning ? 'Stop Scan' : 'Start Scan',
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: viewModel
                            .devices
                            .length, // Sort removed for brevity in this block, but logic remains in ViewModel
                        itemBuilder: (context, index) {
                          // Sort here if needed or rely on VM order
                          final sortedDevices = List.of(viewModel.devices)
                            ..sort((a, b) => b.rssi.compareTo(a.rssi));
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
              ],

              // Loading Overlays
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

              if (viewModel.isSettingUpWifi)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          "Sending Wi-Fi Credentials...",
                          style: TextStyle(color: Colors.white),
                        ),
                        Text(
                          "Please check logs if this hangs.",
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
