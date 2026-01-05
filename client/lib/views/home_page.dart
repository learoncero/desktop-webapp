import 'package:flutter/material.dart';
import 'package:sensor_dash/viewmodels/serial_connection_viewmodel.dart';
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
  late final SerialConnectionViewModel _connectionModel;

  @override
  void initState() {
    super.initState();
    _connectionModel = SerialConnectionViewModel();
  }

  @override
  void dispose() {
    _connectionModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Put the app menu into the appBar so it receives proper bounded constraints.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppMenu(viewModel: _connectionModel),
      ),

      body: ChangeNotifierProvider.value(
        value: _connectionModel,
        child: Column(
          children: [
            SerialConnectionPanel(viewModel: _connectionModel),
            Expanded(child: GraphSection(viewModel: _connectionModel)),
          ],
        ),
      ),
    );
  }
}
