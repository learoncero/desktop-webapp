# Sensor Dash / desktop-webapp

A desktop Flutter application for capturing, visualizing and recording sensor data from serial or UDP sources.

This README explains how to build and run the app, describes CSV recording behavior, and provides troubleshooting tips.

Repository: https://github.com/learoncero/desktop-webapp

---

## Features

- Live plotting of incoming sensor streams (Serial / UDP).
- Connection management (Serial, UDP) and configuration.
- CSV recording of selected sensor values per recording session.
- Load previously recorded CSV files for offline inspection.
- Desktop-targeted UI (Windows, macOS, Linux).

## Requirements

- Flutter SDK (stable channel). See https://flutter.dev for installation.
- Desktop toolchains for the target platform (Windows SDK / Xcode / GTK toolchain).

Recommended: Flutter 3.0+ with desktop support enabled.

## Build & Run (development)

Example for Windows (PowerShell):

1. Install dependencies:

   ```powershell
   flutter pub get
   ```

2. Run the app in debug mode:

   ```powershell
   flutter run -d windows
   ```

For macOS / Linux use `-d macos` / `-d linux` respectively.

## Usage

1. Open the app and select the desired connection type from the menu (Serial or UDP).
2. Configure connection parameters (e.g. COM port / IP address / baud rate / sample format).
3. Click `Connect` to start receiving data. Live plots will update in real time.
4. To record data: enable CSV recording in the recording controls. Each recording session creates a new CSV file.
5. Use `File -> Load CSV` to open previously recorded CSV files.

## Dashboard & Graphs

This application provides an interactive dashboard for live visualization and basic analysis of incoming sensor streams. The dashboard is intended for monitoring real-time data, inspecting trends, and creating short recordings for offline analysis.

Graph elements

- Time axis: a horizontal time axis shows absolute timestamps for samples. The default view displays a rolling time window (configurable in the UI) so the most recent samples are visible.
- Channels (series): each detected sensor channel is displayed as a separate colored series. Channel names come from the incoming packet metadata.
- Legend: the legend lists enabled channels with small color markers and current value readouts when a sample arrives.
- Axis scaling: the graph supports autoscaling (per-channel) and fixed-range modes. Use fixed ranges for comparing channels with known bounds, and autoscale for exploratory views.

Interactions

- Pause/Resume: pause the live plot to freeze the current view for inspection; incoming data is still received and buffered while paused.
- Zoom: click-and-drag or use mouse-wheel to zoom the time axis or value axis (depending on focus). A "reset zoom" control restores the default rolling window.
- Pan: when zoomed in, click-and-drag horizontally to pan older/newer time ranges.
- Enable / Disable channels: toggle channels on/off from the legend or channel panel to reduce visual clutter and CPU usage.
- Hover / Tooltip: hover over the graph to see exact timestamp and per-channel values at that x-position. Tooltips show parsed value and unit if available.
- Snap to sample: tooltips and crosshairs snap to the nearest sample present in the buffer to avoid interpolated values unless explicitly enabled.

Data semantics & export

- Timestamp format: timestamps are recorded as ISO-8601-like UTC timestamps in the CSV (see `lib/services/csv_recorder.dart` for details). All graph time labels are shown in local time by default unless changed in settings.
- Sample rate & ordering: samples are plotted and saved in the order they arrive. The app guards against duplicate timestamps being written to CSV. If packets arrive out of order, the plot will show them in arrival order; CSV recording preserves the single-sample-per-row model.
- Missing channels: if a channel present at recording start disappears later, its CSV column remains in the file and subsequent rows for that column are left empty. The live plot hides disconnected channels by default but keeps them in the channel list.
- Recording & export: starting a recording captures the current set of channels and writes rows for each sample. Use `File -> Load CSV` to re-open exported recordings for offline graphing. CSV file naming includes a timestamp and session id.

## CSV recording behavior

- When a CSV recording starts, the currently available sensor channels are detected and written to the CSV header.
  Example header: `timestamp,temperature_unit,temperature_value`

- Each CSV row represents a single sample with a timestamp and values for the channels present at recording start.

- If a channel that was present at the start disconnects during recording, its CSV fields are left empty for subsequent rows; recording continues.

- Important: The implementation ensures that no duplicate timestamps are written and that no purely empty rows are added to the end of the CSV. Each row represents exactly one sample with a timestamp.

## Tests

This project contains unit tests in the `test/` directory.

- Run tests locally:

  ```powershell
  flutter test
  ```

- Run static analysis:

  ```powershell
  flutter analyze
  ```

## Troubleshooting

- No data after Connect: verify cables and device power, correct port/baud rate, and that no other program holds the port.
- Serial devices not detected on Windows: check drivers, reconnect the device, or reboot the machine.
- Performance issues at very high sample rates: reduce the sample rate, limit the number of plotted channels, or filter channels.

## Contributing

Issues and pull requests are welcome — please open an issue first with a short description and reproduction steps.

- GitHub: https://github.com/learoncero/desktop-webapp
