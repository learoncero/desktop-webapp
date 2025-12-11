import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sensor_data_app/viewmodels/serial_connection_viewmodel.dart';
import 'package:sensor_data_app/widgets/graph_plot.dart';

class GraphSection extends StatefulWidget {
  final SerialConnectionViewModel viewModel;
  const GraphSection({super.key, required this.viewModel});

  @override
  State<GraphSection> createState() => _GraphSectionState();
}

class _GraphSectionState extends State<GraphSection> {
  String? selectedFolderPath;
  bool isRecording = true;

  Future<void> _pickFolder() async {
    try {
      String? folderPath;

      // Prefer file_picker on desktop platforms because it's more reliable for folder picking.
      if (Theme.of(context).platform == TargetPlatform.windows ||
          Theme.of(context).platform == TargetPlatform.macOS ||
          Theme.of(context).platform == TargetPlatform.linux) {
        folderPath = await FilePicker.platform.getDirectoryPath();
      }

      // Fallback to file_selector if running on other platforms or if file_picker returned null.
      folderPath ??= await getDirectoryPath();

      if (!mounted) return;

      if (folderPath != null) {
        setState(() {
          selectedFolderPath = folderPath;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Selected folder: $folderPath')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder selection canceled')),
        );
      }
    } catch (e, st) {
      debugPrint('Error picking folder: $e\n$st');

      if (!mounted) return;

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to pick folder:\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Graph area with sensor selector overlay
        Expanded(
          child: Stack(
            children: [
              // Graph plot
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                alignment: Alignment.center,
                child: ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, child) {
                    return LineChartGraph(
                      spots: widget.viewModel.visibleGraphPoints,
                      displayMax:
                          widget.viewModel.visibleStart.toInt() +
                          widget.viewModel.visibleRange.toInt(),
                      sensorUnit: widget.viewModel.currentSensorUnit,
                    );
                  },
                ),
              ),

              // Sensor selector - top right overlay
              Positioned(
                top: 16,
                right: 16,
                child: ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, child) {
                    final availableSensors = widget.viewModel.availableSensors;
                    final selectedSensor =
                        widget.viewModel.selectedSensorForPlot;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text("Data Stream:"),
                          const SizedBox(width: 8),

                          DropdownButton<String>(
                            value: selectedSensor,
                            hint: Text(
                              'Not connected',
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            items: availableSensors.isEmpty
                                ? null
                                : availableSensors.map((sensor) {
                                    return DropdownMenuItem(
                                      value: sensor,
                                      child: Text(sensor),
                                    );
                                  }).toList(),
                            onChanged: availableSensors.isEmpty
                                ? null
                                : (newSensor) {
                                    if (newSensor != null) {
                                      widget.viewModel.selectSensorForPlot(
                                        newSensor,
                                      );
                                    }
                                  },
                          ),
                          // Show current value if available
                          if (widget.viewModel.currentSample != null) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Text(
                                '${widget.viewModel.currentSample!.value.toStringAsFixed(2)} '
                                '${widget.viewModel.currentSensorUnit ?? ""}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Starttime for plot
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Start Time:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    ListenableBuilder(
                      listenable: widget.viewModel,
                      builder: (context, child) {
                        return Text(
                          widget.viewModel.graphStartTime != ""
                              ? widget.viewModel.graphStartTime
                              : "Not Connected",
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Slider
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListenableBuilder(
                    listenable: widget.viewModel,
                    builder: (context, child) {
                      final max = widget.viewModel.maxGraphWindowStart;
                      final current = widget.viewModel.visibleStart.clamp(
                        0,
                        max,
                      );

                      return Slider(
                        min: 0,
                        max: max > 0 ? max : 0.0001,
                        value: current.toDouble(),
                        onChanged: max == 0
                            ? null
                            : (value) =>
                                  widget.viewModel.updateVisibleStart(value),
                      );
                    },
                  ),
                ),
              ),

              // Reset button for slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ElevatedButton(
                  onPressed: widget.viewModel.resetGraph,
                  child: Text("Back to Current"),
                ),
              ),
            ],
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Record button
            Padding(
              padding: const EdgeInsets.only(bottom: 20, top: 20),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () {
                    setState(() {
                      isRecording = !isRecording;
                    });
                    // Placeholder: start/stop logic goes here
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 70,
                    height: 70,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isRecording ? Colors.red : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isRecording
                          ? null
                          : Border.all(color: Colors.red, width: 4),
                      boxShadow: isRecording
                          ? [
                              BoxShadow(
                                color: const Color.fromRGBO(255, 0, 0, 0.5),
                                blurRadius: 7,
                                spreadRadius: 3,
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      "REC",
                      style: TextStyle(
                        color: isRecording ? Colors.white : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 40),

            // Select folder button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onPressed: _pickFolder,
              child: const Text("Select Save Folder"),
            ),
          ],
        ),

        // Display selected folder path
        if (selectedFolderPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Selected Folder: $selectedFolderPath',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }
}
