import 'dart:async';
import 'dart:convert';
import 'dart:html';

import 'package:beeper_common/admin.dart';
import 'package:beeper_common/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

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

  final loginState = ValueNotifier<LoginStateDto?>(null);
  late WebSocket ws;

  static final Uri websocketUri = baseUri.replace(
    scheme: baseUri.scheme == 'https' ? 'wss' : 'ws',
    path: '/ws',
  );

  static final Uri baseUri = () {
    const defaultConnectString = String.fromEnvironment('base_url');
    if (defaultConnectString.isNotEmpty) {
      return Uri.parse(defaultConnectString);
    }
    return Uri.parse(window.location.href)
        .replace(path: '', query: '')
        .removeFragment();
  }();

  Future<BeeperInfo> start() {
    http.get(baseUri.replace(path: 'state')).then((response) {
      loginState.value = LoginStateDto.fromJson(jsonDecode(response.body));
    });

    if (kDebugMode) {
      print('[Beeper Console] Connecting to $websocketUri');
    }
    ws = WebSocket('$websocketUri');
    final info = Completer<BeeperInfo>();
    ws.onMessage.listen((message) {
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
    });
    return info.future;
  }

  void dispose() {
    ws.close();
  }
}

String timeString(num dt) {
  const rt = <String, double>{
    'millisecond': 0.001,
    'second': 1.0,
    'minute': 60.0,
    'hour': 3600.0,
    'day': 86400.0,
    'week': 604800.0,
    'month': 2629800.0,
  };

  const wt = <String, int>{
    'millisecond': 1000,
    'second': 60,
    'minute': 60,
    'hour': 24,
    'day': 7,
    'week': 7,
    'month': 12,
  };

  if (dt == double.infinity) return 'never';
  if (dt == double.negativeInfinity) return 'forever ago';
  if (dt == double.nan) return 'unknown';

  var sr = '';
  if (dt < 0) {
    sr = 'in ';
    dt = dt.abs();
  }

  String c(String n) {
    final t = (dt / rt[n]!).floor() % wt[n]!;
    return "$t $n${t != 1 ? "s" : ""}";
  }

  if (dt < 1) {
    return "$sr${c("millisecond")}";
  } else if (dt < 60) {
    return "$sr${c("second")}";
  } else if (dt < 3600) {
    return "$sr${c("minute")}";
  } else if (dt < 86400) {
    return "$sr${c("hour")}";
  } else if (dt < 604800) {
    return "$sr${c("day")}";
  } else if (dt < 2629800) {
    return "$sr${c("week")}";
  } else {
    return "$sr${c("month")}";
  }
}

class ConsoleConnectionManager {
  final statuses = <String, dynamic>{};

  late BeeperConnection connection;
  late BeeperInfo info;

  void updateDiscordStatus(dynamic data) {
    final dynamic user = data['user'];
    if (user != null) {
      querySelector('#status-avatar')!.style.backgroundImage =
          'url("${user['avatar']}")';
      querySelector('#status-name')!.text =
          'Connected as ${user['name']}#${user['discriminator']}';
    }
  }

  void updateStatus(String module, dynamic data) {
    if (module == '/discord') {
      updateDiscordStatus(data);
    }

    if (data == null) {
      statuses.remove(module);
    } else {
      statuses[module] = data;
    }
  }

  String formatDate(DateTime date) => DateFormat.yMMMMd().format(date);
  String formatDatePrecise(DateTime date) => DateFormat.jms().format(date);

  void updateStatsList() {
    final stats = <String, dynamic>{
      'Online since': formatDate(info.started),
      if (statuses['/discord'] != null) ...<String, dynamic>{
        'Snowflake': statuses['/discord']['user']['id'],
        'Guilds': statuses['/discord']['guilds'],
      },
    };

    querySelector('#stats-list')!.children = [
      for (final entry in stats.entries)
        LIElement()
          ..children = [
            SpanElement()
              ..classes.add('key')
              ..text = entry.key,
            SpanElement()..text = entry.value.toString(),
          ]
    ];
  }

  void addLogEvent(LogEvent event) {
    querySelector('#logs-view')!.children.add(
          DivElement()
            ..classes.add('log-event')
            ..children.addAll([
              DivElement()
                ..classes.add('log-timestamp')
                ..text = formatDatePrecise(event.time),
              DivElement()
                ..classes.add('log-service')
                ..text = event.name,
              PreElement()
                ..classes.add('log-content')
                ..text = event.content,
            ]),
        );
  }

  Timer? timer;

  void startTimer() {
    void updateTime() {
      final now = DateTime.now().millisecondsSinceEpoch;
      final started = info.started.millisecondsSinceEpoch;
      querySelector('#header-uptime')!.text =
          'Up ${timeString((now - started) / 1000)}';
    }

    updateTime();
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      updateTime();
    });
  }
}
