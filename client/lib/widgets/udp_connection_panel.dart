import 'package:flutter/material.dart';
import 'package:sensor_dash/viewmodels/udp_connection_viewmodel.dart';

class UdpConnectionPanel extends StatelessWidget {
  final UdpConnectionViewModel viewModel;

  const UdpConnectionPanel({super.key, required this.viewModel});

  Future<void> handleConnect(BuildContext context) async {
    final error = await viewModel.connect();

    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  void handleDisconnect(BuildContext context) {
    viewModel.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Row(
            children: [
              Text("Address:"),
              const SizedBox(width: 8),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: viewModel.isConnected
                      ? null
                      : viewModel.updateAddress,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  enabled: !viewModel.isConnected,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Address',
                    hintStyle: TextStyle(fontWeight: FontWeight.normal),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Text("Port:"),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: viewModel.isConnected
                      ? null
                      : viewModel.updatePort,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  enabled: !viewModel.isConnected,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Port',
                    hintStyle: TextStyle(fontWeight: FontWeight.normal),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              ElevatedButton(
                onPressed: viewModel.isConnected
                    ? () => handleDisconnect(context)
                    : () => handleConnect(context),
                child: Text(viewModel.isConnected ? 'Disconnect' : 'Connect'),
              ),
            ],
          ),
        );
      },
    );
  }
}
