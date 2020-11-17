import 'dart:convert';
import 'dart:html';
import 'package:rxdart/subjects.dart';
import 'package:websocket/websocket.dart';

class BeeperStatus {
  DateTime started;

  static BeeperStatus fromJson(dynamic data) {
    return BeeperStatus()
      ..started = DateTime.fromMillisecondsSinceEpoch(data['started'] as int);
  }
}

class BeeperConnection {
  BehaviorSubject<BeeperStatus> status;
  WebSocket ws;

  void start(Uri uri) async {
    ws = await WebSocket.connect(uri.toString());
    await for (final message in ws.stream) {
      final dynamic data = jsonDecode(message as String);
      final type = data['t'] as String;
      if (type == 'status') {
        status.add(BeeperStatus.fromJson(data['d']));
      }
    }
  }
}