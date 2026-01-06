import 'package:flutter/material.dart';

enum ConnectionType { serial, udp }

extension ConnectionTypeX on ConnectionType {
  String get label {
    switch (this) {
      case ConnectionType.serial:
        return 'Serial';
      case ConnectionType.udp:
        return 'UDP';
    }
  }
}

class ConnectionSelectionViewmodel extends ChangeNotifier {
  static const List<ConnectionType> availableConnections =
      ConnectionType.values;

  ConnectionType _currentConnection = ConnectionType.serial;

  ConnectionType get currentConnection => _currentConnection;

  void selectCurrentConnection(ConnectionType connection) {
    if (_currentConnection == connection) return;
    _currentConnection = connection;
    notifyListeners();
  }
}
