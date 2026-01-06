import 'package:flutter/material.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';
import 'package:sensor_dash/viewmodels/connection_selection_viewmodel.dart';
import 'package:sensor_dash/viewmodels/serial_connection_viewmodel.dart';
import 'package:sensor_dash/viewmodels/udp_connection_viewmodel.dart';
import 'package:sensor_dash/widgets/connection_selection_panel.dart';
import 'package:sensor_dash/widgets/udp_connection_panel.dart';
import '../main.dart';
import '../widgets/graph_section.dart';
import '../widgets/serial_connection_panel.dart';
import 'app_menu.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ConnectionSelectionViewmodel _connectionSelectionViewmodel;
  late final Map<ConnectionType, ConnectionBaseViewModel> _connectionViewModels;

  @override
  void initState() {
    super.initState();

    _connectionViewModels = {
      ConnectionType.serial: SerialConnectionViewModel(),
      ConnectionType.udp: UdpConnectionViewModel(),
    };

    _connectionSelectionViewmodel = ConnectionSelectionViewmodel();
  }

  @override
  void dispose() {
    for (final vm in _connectionViewModels.values) {
      vm.dispose();
    }
    _connectionSelectionViewmodel.dispose();
    super.dispose();
  }

  Widget _buildConnectionPanel(ConnectionType type) {
    switch (type) {
      case ConnectionType.serial:
        return SerialConnectionPanel(
          viewModel: _connectionViewModels[type]! as SerialConnectionViewModel,
        );

      case ConnectionType.udp:
        return UdpConnectionPanel(
          viewModel: _connectionViewModels[type]! as UdpConnectionViewModel,
        );
    }
  }

  ConnectionBaseViewModel? get _csvOwnerVm {
    for (final vm in _connectionViewModels.values) {
      if (vm.isCsvMode) return vm;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Put the app menu into the appBar so it receives proper bounded constraints.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _connectionSelectionViewmodel,
            ..._connectionViewModels.values,
          ]),
          builder: (context, _) {
            final currentVm =
                _connectionViewModels[_connectionSelectionViewmodel
                    .currentConnection]!;

            return AppMenu(
              currentThemeMode: MyApp.getThemeMode(context),
              connectionBaseViewModel: currentVm,
            );
          },
        ),
      ),

      body: ChangeNotifierProvider.value(
        value: _connectionSelectionViewmodel,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _connectionSelectionViewmodel,
            ..._connectionViewModels.values,
          ]),
          builder: (context, _) {
            final currentType = _connectionSelectionViewmodel.currentConnection;
            final currentVm = _connectionViewModels[currentType]!;
            final csvVm = _csvOwnerVm;
            final graphVm = csvVm ?? currentVm;

            return Column(
              children: [
                csvVm != null
                    ? Container(
                        padding: const EdgeInsets.all(16),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'CSV: ${csvVm.loadedCsvPath?.split(r'\').last.split('/').last}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: csvVm.closeCsvFile,
                              icon: const Icon(Icons.close, size: 16),
                              label: const Text("Close CSV"),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        child: Row(
                          children: [
                            ConnectionSelectionPanel(
                              viewModel: _connectionSelectionViewmodel,
                              connectionVm: currentVm,
                            ),
                            _buildConnectionPanel(currentType),
                          ],
                        ),
                      ),

                Expanded(child: GraphSection(viewModel: graphVm)),
              ],
            );
          },
        ),
      ),
    );
  }
}
