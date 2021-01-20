import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:beeper_common/logging.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxdart/subjects.dart' show BehaviorSubject;

import 'package:beeper/discord/http.dart';

abstract class Op {
  Op._();
  static const int dispatch = 0;
  static const int heartbeat = 1;
  static const int identify = 2;
  static const int presenceUpdate = 3;
  static const int voiceStateUpdate = 4;
  static const int voiceGuildPing = 5;
  static const int resume = 6;
  static const int reconnect = 7;
  static const int requestGuildMembers = 8;
  static const int invalidSession = 9;
  static const int hello = 10;
  static const int heartbeatAck = 11;
}

abstract class Intents {
  Intents._();
  static const int guilds = 1;
  static const int guildMembers = 1 << 1;
  static const int guildBans = 1 << 2;
  static const int guildEmojis = 1 << 3;
  static const int guildIntegrations = 1 << 4;
  static const int guildWebhooks = 1 << 5;
  static const int guildInvites = 1 << 6;
  static const int guildVoiceStates = 1 << 7;
  static const int guildPresences = 1 << 8;
  static const int guildMessages = 1 << 9;
  static const int guildMessageReactions = 1 << 10;
  static const int guildMessageTyping = 1 << 11;
  static const int directMessages = 1 << 12;
  static const int directMessageReactions = 1 << 13;
  static const int directMessageTyping = 1 << 14;
}

class _NoData {
  const _NoData();
  static const instance = _NoData();
}

class DiscordConnectionState {
  final bool isStarted;
  final bool isError;
  final bool isConnected;
  final bool isWaiting;
  final String reason;

  DiscordConnectionState._({
    this.isStarted = true,
    this.isError = false,
    this.isConnected = false,
    this.isWaiting = false,
    this.reason,
  });

  factory DiscordConnectionState.stopped() => DiscordConnectionState._(
    isStarted: false,
  );

  factory DiscordConnectionState.started() => DiscordConnectionState._();

  factory DiscordConnectionState.connected() => DiscordConnectionState._(
    isConnected: true,
  );

  factory DiscordConnectionState.error({
    @required String reason,
  }) => DiscordConnectionState._(
    isError: true,
    isWaiting: true,
    reason: reason,
  );

  factory DiscordConnectionState.waiting({
    @required String reason,
  }) => DiscordConnectionState._(
    isWaiting: true,
    reason: reason,
  );
}

class DiscordConnection {
  final HttpService http;
  final String _token;

  DiscordConnection({
    @required String token,
    this.http,
  }) : _token = token.trim();

  void Function(String name, Object data) onEvent;

  WebSocket _socket;
  int _heartbeatInterval;
  Timer _heartbeatTimer;
  var _heartbeatResponse = false;
  int _heartbeatSequence;

  final _stateSubject = BehaviorSubject.seeded(DiscordConnectionState.stopped());
  DiscordConnectionState get state => _stateSubject.value;
  ValueStream<DiscordConnectionState> get states => _stateSubject.stream;

  void send(int op, [dynamic data = _NoData.instance]) {
    final payload = jsonEncode(<String, dynamic>{
      'op': op,
      if (data != _NoData.instance) 'd': data,
    });
    _socket.add(payload);
  }

  void _sendHeartbeat() {
    send(Op.heartbeat, _heartbeatSequence);
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
    _heartbeatSequence = payload['s'] as int ?? _heartbeatSequence;
    final name = payload['t'] as String;

    if (op == Op.dispatch) {
      if (name == 'READY') {
        _stateSubject.value = DiscordConnectionState.connected();
        retries = 0;
      }
      logger.log('discord', '< $message', level: LogLevel.verbose);
      onEvent(name, data);
    } else if (op == Op.hello) {
      _heartbeatInterval = data['heartbeat_interval'] as int;
      _sendHeartbeat();
      send(Op.identify, {
        'token': _token,
        'intents': Intents.guilds | Intents.directMessages | Intents.guildMessages,
        'properties': {
          '\$os': Platform.operatingSystem,
          '\$browser': 'beep',
          '\$device': 'boop',
        },
      });
    } else if (op == Op.heartbeatAck) {
      _heartbeatResponse = true;
    } else {
      logger.log('discord', '< $message', level: LogLevel.verbose);
      logger.log('discord', 'Unknown opcode: $op', level: LogLevel.verbose);
    }
  }

  void start() async {
    while (true) {
      _stateSubject.value = DiscordConnectionState.started();
      retries = min(20, retries + 1);
      int remaining;
      int resetAfter;
      try {
        final dynamic response = await http.get('/gateway/bot');
        assert(response['shards'] == 1, 'Multiple shards not supported');
        remaining = response['session_start_limit']['remaining'] as int;
        resetAfter = response['session_start_limit']['reset_after'] as int;

        logger.log('discord', 'remaining: $remaining');
        logger.log('discord', 'resetAfter: ${resetAfter / 1000}s');

        if (remaining < 10) {
          _stateSubject.value = DiscordConnectionState.waiting(
            reason: 'Ran out of connects, waiting for $resetAfter ms.',
          );
          await Future<void>.delayed(Duration(milliseconds: resetAfter));
        }

        final url = response['url'] as String;
        _socket = await WebSocket.connect(url + '?v=6&encoding=json');
        await _socket.forEach(_handle);
        logger.log('discord', 'closed: ${_socket.closeCode} (${_socket.closeReason})');
        var reason = 'Socket closed with code ${_socket.closeCode}';
        if (_socket.closeReason != null && _socket.closeReason.isNotEmpty) {
          reason += ' (${_socket.closeReason})';
        }
        _stateSubject.value = DiscordConnectionState.waiting(reason: reason);
      } catch (e, bt) {
        logger.log('discord', 'Failed to connect to gateway: $e\n$bt', level: LogLevel.error);
        _stateSubject.value = DiscordConnectionState.error(reason: '$e\n$bt');
      }
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      var wait = retries * 5000;
      if (remaining != null) {
        wait = max(wait, resetAfter ~/ remaining);
      }
      logger.log('discord', 'Waiting ${wait / 1000}s to reconnect');
      await Future<void>.delayed(
        Duration(milliseconds: wait),
      );
    }
  }
}