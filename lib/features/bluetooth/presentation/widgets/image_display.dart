import 'package:flutter/material.dart';
import '../viewmodels/bluetooth_viewmodel.dart';

class ImageDisplay extends StatelessWidget {
  final BluetoothViewModel viewModel;

  const ImageDisplay({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    if (viewModel.photoJustSaved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto guardada en el tab Fotos')),
        );
        viewModel.clearPhotoJustSaved();
      });
    }
    return Column(
      children: [
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
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_not_supported,
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
                          if (viewModel.imageHeaderHex != null) ...[
                            Padding(
                              padding: const EdgeInsets.all(8.0),
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
                                viewModel.lastImage!.length > 10)
                              Padding(
                                padding: const EdgeInsets.all(8.0),
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
    );
  }
}
