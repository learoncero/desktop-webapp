import 'package:flutter/material.dart';
import 'package:sensor_data_app/viewmodels/serial_connection_viewmodel.dart';
import '../main.dart';
import '../widgets/graph_section.dart';
import '../widgets/serial_connection_panel.dart';
import 'app_menu.dart';

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
        child: AppMenu(
          currentThemeMode: MyApp.getThemeMode(context),
          viewModel: _connectionModel,
        ),
      ),

      body: Column(
        children: [
          SerialConnectionPanel(viewModel: _connectionModel),
          Expanded(child: GraphSection(viewModel: _connectionModel)),
        ],
      ),
    );
  }
}
