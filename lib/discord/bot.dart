import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:beeper/discord/http.dart';
import 'package:beeper/discord/opcodes.dart';

import 'package:meta/meta.dart';

class _NoData {
  const _NoData();
  static const instance = _NoData();
}

class Discord {
  final String token;
  final HttpService httpService;

  Discord({@required this.token}) : httpService = HttpService(
    baseUri: Uri.parse('https://discord.com/api/v7'),
    userAgent: 'Beeper (https://github.com/PixelToast/beeper-bot, eternal beta)',
    authorization: 'Bot $token',
  ), assert(token != null);

  WebSocket _socket;
  int _heartbeatInterval;
  Timer _heartbeatTimer;
  var _heartbeatResponse = false;
  int _heartbeatSequence;

  void _send(int op, [dynamic data = _NoData.instance]) {
    final payload = jsonEncode(<String, dynamic>{
      'op': op,
      if (data != _NoData.instance) 'd': data,
    });
    if (op != Op.heartbeat) {
      print('> $payload');
    }
    _socket.add(payload);
  }

  void _sendHeartbeat() {
    _send(Op.heartbeat, _heartbeatSequence);
    _heartbeatTimer = Timer(Duration(milliseconds: _heartbeatInterval), _heartbeat);
  }

  void _heartbeat() {
    if (_heartbeatResponse) {
      _sendHeartbeat();
      _heartbeatResponse = false;
    } else {
      _socket.close(4009, 'Session timed out');
    }
  }

  var retries = 0;

  void _handle(dynamic message) {
    final dynamic payload = jsonDecode(message as String);
    final dynamic data = payload['d'];
    final op = payload['op'] as int;
    _heartbeatSequence = payload['s'] as int;
    final name = payload['t'] as String;

    if (op == Op.dispatch) {
      if (name == 'READY') {
        retries = 0;
      }
      print('< $message');
    } else if (op == Op.hello) {
      _heartbeatInterval = data['heartbeat_interval'] as int;
      _sendHeartbeat();
      _send(Op.identify, {
        'token': token,
        'intents': Intents.guildMessages,
        'properties': {
          '\$os': Platform.operatingSystem,
          '\$browser': 'beep',
          '\$device': 'boop',
        },
      });
    } else if (op == Op.heartbeatAck) {
      _heartbeatResponse = true;
    } else {
      print('< $message');
      stderr.writeln('unknown opcode: $op');
    }
  }

  Future<void> initialize() async {
    while (true) {
      retries = min(20, retries + 1);
      int remaining;
      int resetAfter;
      try {
        final dynamic response = await httpService.get('/gateway/bot');
        assert(response['shards'] == 1, 'Multiple shards not supported');
        remaining = response['session_start_limit']['remaining'] as int;
        resetAfter = response['session_start_limit']['reset_after'] as int;
        print('remaining: $remaining');
        print('resetAfter: ${resetAfter / 1000}s');
        final url = response['url'] as String;
        _socket = await WebSocket.connect(url + '?v=6&encoding=json');
        await _socket.forEach(_handle);
        print('closed: ${_socket.closeCode} (${_socket.closeReason})');
      } catch (e, bt) {
        stderr.writeln('$e\n$bt');
      }
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      var wait = retries * 5000;
      if (remaining != null) {
        wait = max(wait, resetAfter ~/ remaining);
      }
      print('waiting ${wait / 1000}s');
      await Future<void>.delayed(
        Duration(milliseconds: wait),
      );
    }
  }
}