import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';

class CameraPage extends StatelessWidget {
  final String ipAddress;

  const CameraPage({super.key, required this.ipAddress});

  @override
  Widget build(BuildContext context) {
    // Standard ESP32-CAM stream URL often looks like http://<ip>/stream
    // Firmware is configured to run on port 80
    final String streamUrl = "http://$ipAddress/stream";

    return Scaffold(
      appBar: AppBar(title: const Text("Live Camera")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Mjpeg(
                isLive: true,
                error: (context, error, stack) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(height: 8),
                        Text("Error: $error"),
                        const SizedBox(height: 8),
                        Text("URL: $streamUrl"),
                      ],
                    ),
                  );
                },
                stream: streamUrl,
              ),
            ),
            const SizedBox(height: 16),
            const Text("Streaming from OMI Glasses"),
          ],
        ),
      ),
    );
  }
}
