import 'package:flutter/material.dart';
import 'package:sensor_dash/viewmodels/serial_connection_viewmodel.dart';

class SerialConnectionPanel extends StatefulWidget {
  final SerialConnectionViewModel viewModel;

  const SerialConnectionPanel({super.key, required this.viewModel});

  @override
  State<SerialConnectionPanel> createState() => _SerialConnectionPanelState();
}

class _SerialConnectionPanelState extends State<SerialConnectionPanel> {
  SerialConnectionViewModel get viewModel => widget.viewModel;

  Future<void> _handleConnect(BuildContext context) async {
    var cancelled = false;
    var dialogShown = false;

    // Schedule dialog after 250ms if still connecting
    Future.delayed(const Duration(milliseconds: 250)).then((_) {
      if (cancelled) return;
      if (!context.mounted) return;
      if (viewModel.isConnecting) {
        dialogShown = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('Connecting...'),
              content: Row(
                children: const [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(),
                  ),
                  SizedBox(width: 16),
                  Expanded(child: Text('Please wait while connecting.')),
                ],
              ),
            );
          },
        );
      }
    });

    final error = await viewModel.connect();

    cancelled = true; // Cancel pending dialog-show and close if open

    if (dialogShown && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

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

  Future<void> _handleRefreshPorts(BuildContext context) async {
    await viewModel.refreshPorts();
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder automatically rebuilds when model.notifyListeners() is called
    return SizedBox(
      height: 64,
      child: ListenableBuilder(
        listenable: viewModel,
        builder: (context, child) {
          // Show error message as SnackBar if present
          if (viewModel.errorMessage != null) {
            final errorMsg = viewModel.errorMessage!;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMsg),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
                viewModel.clearError();
              }
            });
          }

          final disabling = viewModel.isConnected || viewModel.isConnecting;

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
                  onChanged: disabling
                      ? null // Lock when connected or connecting
                      : (value) => viewModel.selectBaudrate(value!),
                ),
                const SizedBox(width: 24),
                const Text("Port:"),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: viewModel.selectedPort,
                  items: viewModel.availablePorts
                      .map(
                        (port) =>
                            DropdownMenuItem(value: port, child: Text(port)),
                      )
                      .toList(),
                  onChanged: disabling
                      ? null // Lock when connected or connecting
                      : (value) => viewModel.selectPort(value),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: viewModel.isScanning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: viewModel.isConnected || viewModel.isScanning || viewModel.isConnecting
                      ? null // Disable when connected, scanning, or connecting
                      : () => _handleRefreshPorts(context),
                  tooltip: 'Refresh Ports',
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: viewModel.isConnecting
                      ? null
                      : viewModel.isConnected
                          ? () => _handleDisconnect(context)
                          : () => _handleConnect(context),
                  child: viewModel.isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(viewModel.isConnected ? "Disconnect" : "Connect"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
