import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:beeper_common/logging.dart';

class BeeperInfo {
  late DateTime started;
  String? version;

  static BeeperInfo fromJson(dynamic data) {
    return BeeperInfo()
      ..started = DateTime.fromMillisecondsSinceEpoch(data['started'] as int)
      ..version = data['version'] as String?;
  }
}

class BeeperConnection {
  final Function(String module, dynamic data) onStatusUpdate;
  final Function(LogEvent event) onLogEvent;

  BeeperConnection({
    required this.onStatusUpdate,
    required this.onLogEvent,
  });

  final info = Completer<BeeperInfo>();
  late WebSocket ws;

  void _start(Uri uri) async {
    print('[Beeper Console] Connecting to $uri');
    ws = WebSocket(uri.toString());
    await for (final message in ws.onMessage) {
      print('message! ${message.data}');
      final dynamic data = jsonDecode(message.data as String);
      final type = data['t'] as String?;
      if (type == 'status') {
        info.complete(BeeperInfo.fromJson(data['d']));
        final statuses = data['d']['statuses'] as Map<String, dynamic>;
        for (final entry in statuses.entries) {
          onStatusUpdate(entry.key, entry.value);
        }
        for (final event in data['d']['logs'] as List<dynamic>) {
          onLogEvent(LogEvent.fromJson(event));
        }
      } else if (type == 'status_update') {
        onStatusUpdate(data['m'] as String, data['d']);
      } else if (type == 'log') {
        onLogEvent(LogEvent.fromJson(data['d']));
      }
    }
  }

  Future<BeeperInfo> start(Uri uri) {
    _start(uri);
    return info.future;
  }
}
