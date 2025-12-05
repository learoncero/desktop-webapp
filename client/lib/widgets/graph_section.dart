import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:file_picker/file_picker.dart';

class GraphSection extends StatefulWidget {
  const GraphSection({super.key});

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
        // Placeholder for the sensor graph
        Expanded(
          child: Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: Text(
              'Sensor Graph Placeholder',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 22,
              ),
            ),
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
