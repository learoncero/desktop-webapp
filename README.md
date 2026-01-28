# Sensor Dash / desktop-webapp

A desktop Flutter application for capturing, visualizing and recording sensor data from serial or UDP sources.

This README explains how to build and run the app, describes CSV recording behavior, and provides troubleshooting tips.

Repository: https://github.com/learoncero/desktop-webapp

---

## Features

- Connection management (Serial, UDP) and configuration.
- Live plotting of incoming sensor streams (over Serial / UDP at one time).
- CSV recording of selected sensor values per recording session.
- Load previously recorded CSV files for inspection.
- Desktop-targeted UI (Windows, macOS, Linux).

<p align="center">
<img src="images/Ubuntu_Plot.png" alt="SensorDash showing recording" width="500">
<img src="images/Ubuntu_Settings.png" alt="SensorDash showing settings" width="500">
</p>

## Requirements

- Flutter SDK. See https://flutter.dev for installation.
- Desktop toolchains for the target platform (Windows SDK / Xcode / GTK toolchain).

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
2. Configure connection parameters (e.g. COM port / IP address / baud rate / sample format in settings).
3. Click `Connect` to start receiving data. Live plots will update in real time. and show on the graph
4. Each recording session creates a new CSV file with the available data streams.
5. Use `File -> Load CSV` to open previously recorded CSV files.

## Dashboard & Graphs

This application provides an interactive dashboard for live visualization of incoming sensor streams. The dashboard is intended for monitoring real-time data, inspecting trends, and creating recordings for later analysis.

Graph elements

- Time axis: a horizontal time axis shows absolute timestamps for samples. The default view displays a rolling time window of 60s (configurable in the UI), so the most recent samples are visible. The number of displayed seconds can be changed in the settings.
- Datastreams: Datastreams come from the incoming source. Only one datastream can be displayed at once, but the history since starting the recording is saved, when changing the stream.

Interactions

- Connect and Disconnect: Connecting to a datsource by setting the correct information and clicking on connect.
- Over UDP the available COM-Ports need to be refreshed
- Start and Stop Recording: Click on the Record Button to start and stop recording. A file will be created with the current time in the selected folder, that saves the data as a csv.

Data semantics & export

- Timestamp format: timestamps are recorded in the CSV (see `lib/services/csv_recorder.dart` for details). All graph time labels are shown in local time by default.
- Sample rate & ordering: samples are plotted and saved in the order they arrive. CSV recording saves a single sample per row.
- Datassteram: if a datastream is present at recording start disappears later, its CSV column remains in the file and subsequent rows for that column are left empty. The live plot hides disconnected datastreams but keeps them in the datastreams list.
- Recording & export: starting a recording captures the current set of datastreams and writes rows for each sample.

## CSV recording behavior

- When a CSV recording starts, the currently available sensor datastreams are detected and written to the CSV header.
  Example header: `timestamp,temperature_unit,temperature_value`
- Each CSV row represents a single sample with a timestamp and values for the datastream present at recording start.
- If a datastream that was present at the start disconnects during recording, its CSV fields are left empty for subsequent rows; recording continues.
- Each row represents exactly one sample with a timestamp.

## Tests

This project contains unit tests for the simulated serial port behaviour in the `test/` directory.

- Run tests locally:

  ```powershell
  flutter test
  ```

- Run static analysis:

  ```powershell
  flutter analyze
  ```

## Possible Improvements

- **Serial connection and port selection**\
  The current library used for establishing the serial connection and selecting ports is unreliable and occasionally causes the application to freeze completely. Alternative libraries should be evaluated and tested for better stability.

- **Statistics scope (time range selection)**\
  Currently, all statistics are calculated over the entire recorded time span. An option to switch between statistics for the full dataset and statistics limited to the currently visible time window could be added.

- **User-defined CSV headers for incoming data**\
  The application currently does not allow customization of CSV headers. A mechanism that lets users define column headers that correspond to the structure and semantics of the data they transmit to the application could be introduced.

- **Graph layout and UI overlap**\
  The graph plot is partially hidden behind the data stream dropdown menu. The UI layout should be adjusted to prevent overlapping elements and ensure the graph remains fully visible.

- **Data format support for incoming data**\
  Support for incoming data formats could be expanded. Currently, the application only accepts JSON and a predefined CSV format.

- **Multiple sensor support**\
  The serial connection has only been tested with a single sensor that continuously transmits data. Sensors that require prior configuration or explicit start/stop commands are currently not supported by the application.

- **Out-of-order data handling and timestamps**\
  Incoming data is timestamped by the application upon reception and no checks are performed for out-of-order arrival. As a result, delayed or reordered data packets are not detected or handled. Future improvements could include validating data order or supporting sensor-provided timestamps.
