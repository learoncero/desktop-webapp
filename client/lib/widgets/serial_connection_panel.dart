import 'package:flutter/material.dart';
import 'package:sensor_dash/viewmodels/serial_connection_viewmodel.dart';

class SerialConnectionPanel extends StatelessWidget {
  final SerialConnectionViewModel viewModel;

  const SerialConnectionPanel({super.key, required this.viewModel});

  Future<void> _handleConnect(BuildContext context) async {
    final error = await viewModel.connect();

    if (!context.mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
    }
  }

  void _handleDisconnect(BuildContext context) {
    viewModel.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder automatically rebuilds when model.notifyListeners() is called
    return SizedBox(
      height: 64,
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Row(
              children: [
                // Serial connection controls
                const Text("Baudrate:"),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: viewModel.selectedBaudrate,
                  items: SerialConnectionViewModel.availableBaudrates
                      .map(
                        (baudrate) => DropdownMenuItem(
                          value: baudrate,
                          child: Text(baudrate.toString()),
                        ),
                      )
                      .toList(),
                  onChanged: viewModel.isConnected
                      ? null // Lock when connected
                      : (value) => viewModel.selectBaudrate(value!),
                ),
                const SizedBox(width: 24),
                const Text("Port:"),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: viewModel.selectedPort,
                  items: SerialConnectionViewModel.availablePorts
                      .map(
                        (port) =>
                            DropdownMenuItem(value: port, child: Text(port)),
                      )
                      .toList(),
                  onChanged: viewModel.isConnected
                      ? null // Lock when connected
                      : (value) => viewModel.selectPort(value),
                ),
                const SizedBox(width: 24),
                ElevatedButton(
                  onPressed: viewModel.isConnected
                      ? () => _handleDisconnect(context)
                      : () => _handleConnect(context),
                  child: Text(viewModel.isConnected ? "Disconnect" : "Connect"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
