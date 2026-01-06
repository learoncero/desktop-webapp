import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:sensor_dash/viewmodels/connection_base_viewmodel.dart';
import 'package:sensor_dash/widgets/graph_plot.dart';

class GraphSection extends StatefulWidget {
  final ConnectionBaseViewModel viewModel;
  const GraphSection({super.key, required this.viewModel});

  @override
  State<GraphSection> createState() => _GraphSectionState();
}

class _GraphSectionState extends State<GraphSection> {
  Future<void> _pickFolder(ConnectionBaseViewModel vm) async {
    try {
      String? folderPath;

      if (Theme.of(context).platform == TargetPlatform.windows ||
          Theme.of(context).platform == TargetPlatform.macOS ||
          Theme.of(context).platform == TargetPlatform.linux) {
        try {
          folderPath = await FilePicker.platform.getDirectoryPath();
        } catch (e) {
          debugPrint('FilePicker failed, falling back to file_selector: $e');
          folderPath = await getDirectoryPath();
        }
      } else {
        // Non-desktop platforms: use file_selector directly
        folderPath = await getDirectoryPath();
      }

      if (!mounted) return;

      if (folderPath != null) {
        // Save to viewmodel so recorder can pick it up
        vm.setSaveFolderPath(folderPath);

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
    final vm = widget.viewModel;

    final selectedFolderPath = vm.saveFolderPath;

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
                      visibleRange: widget.viewModel.visibleRange.toInt(),
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
                          if ((widget.viewModel.currentSamples != null) &&
                              (widget.viewModel.isRecording)) ...[
                            const SizedBox(width: 12),
                            Builder(
                              builder: (context) {
                                // Find the sample for the selected sensor
                                final selectedSample = widget
                                    .viewModel
                                    .currentSamples!
                                    .firstWhere(
                                      (sample) =>
                                          sample.dataStream == selectedSensor,
                                      orElse: () => widget
                                          .viewModel
                                          .currentSamples!
                                          .first,
                                    );

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    '${selectedSample.value.toStringAsFixed(2)} '
                                    '${selectedSample.dataUnit}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              },
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
                              : 'Not recording',
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Statistics panel
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (context, child) {
                    final minVal = widget.viewModel.minValue;
                    final maxVal = widget.viewModel.maxValue;
                    final avgVal = widget.viewModel.avgValue;
                    final hasData = minVal != double.infinity;

                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outline,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStatItem(
                            context,
                            "Min",
                            hasData ? minVal.toStringAsFixed(2) : "—",
                            widget.viewModel.currentSensorUnit ?? "",
                          ),
                          const SizedBox(width: 12),
                          _buildStatItem(
                            context,
                            "Max",
                            hasData ? maxVal.toStringAsFixed(2) : "—",
                            widget.viewModel.currentSensorUnit ?? "",
                          ),
                          const SizedBox(width: 12),
                          _buildStatItem(
                            context,
                            "Avg",
                            hasData ? avgVal.toStringAsFixed(2) : "—",
                            widget.viewModel.currentSensorUnit ?? "",
                          ),
                        ],
                      ),
                    );
                  },
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

        ListenableBuilder(
          listenable: widget.viewModel,
          builder: (context, child) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Record button
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 20),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(40),
                      onTap: widget.viewModel.isConnected
                          ? widget.viewModel.toggleRecording
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 70,
                        height: 70,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.viewModel.isRecording
                              ? Colors.red
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: widget.viewModel.isRecording
                              ? null
                              : Border.all(color: Colors.red, width: 4),
                          boxShadow: widget.viewModel.isRecording
                              ? [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.6),
                                    blurRadius: 7,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : [],
                        ),
                        child: Text(
                          "REC",
                          style: TextStyle(
                            color: widget.viewModel.isRecording
                                ? Colors.white
                                : widget.viewModel.isConnected
                                ? Colors.red
                                : Colors.grey,
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
                  onPressed: () => _pickFolder(widget.viewModel),
                  child: const Text("Select Save Folder"),
                ),
              ],
            );
          },
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

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    String unit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value + (unit.isNotEmpty && value != "—" ? " $unit" : ""),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
