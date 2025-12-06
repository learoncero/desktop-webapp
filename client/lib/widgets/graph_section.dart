import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:sensor_data_app/viewmodels/serial_connection_viewmodel.dart';

class GraphSection extends StatefulWidget {
  const GraphSection({super.key});

  @override
  State<GraphSection> createState() => _GraphSectionState();
}

class _GraphSectionState extends State<GraphSection> {
  bool isRecording = true;

  Future<void> _pickFolder(SerialConnectionViewModel vm) async {
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
        // Save to viewmodel so recorder can pick it up
        vm.setSaveFolderPath(folderPath);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected folder: $folderPath')),
        );
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
    final vm = Provider.of<SerialConnectionViewModel>(context);
    final selectedFolderPath = vm.saveFolderPath;

    return Column(
      children: [
        // Placeholder for the sensor graph
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.black87,
            alignment: Alignment.center,
            child: Text(
              'Sensor Graph Placeholder',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 22
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Record button
            Material(
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
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isRecording ? Colors.red : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isRecording ? null : Border.all(color: Colors.red, width: 4),
                    boxShadow: isRecording
                        ? [
                      BoxShadow(
                        color: const Color.fromRGBO(255, 0, 0, 0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ] : [],
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

            const SizedBox(width: 40),

            // Select folder button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onPressed: () => _pickFolder(vm),
              child: const Text("Select Save Folder"),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Display selected folder path
        if (selectedFolderPath != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Selected Folder: $selectedFolderPath',
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }
}
