import 'package:flutter/material.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';
import 'package:sensor_dash/viewmodels/connection_selection_viewmodel.dart';

class ConnectionSelectionPanel extends StatelessWidget {
  final ConnectionSelectionViewmodel viewModel;
  final ConnectionBaseViewModel connectionVm;

  const ConnectionSelectionPanel({
    super.key,
    required this.viewModel,
    required this.connectionVm,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([viewModel, connectionVm]),
      builder: (context, _) {
        return DropdownButton<ConnectionType>(
          value: viewModel.currentConnection,
          items: ConnectionSelectionViewmodel.availableConnections
              .map(
                (type) => DropdownMenuItem<ConnectionType>(
                  value: type,
                  child: Text(type.label),
                ),
              )
              .toList(),
          onChanged: connectionVm.isConnected
              ? null
              : (type) {
                  if (type != null) {
                    viewModel.selectCurrentConnection(type);
                  }
                },
        );
      },
    );
  }
}
