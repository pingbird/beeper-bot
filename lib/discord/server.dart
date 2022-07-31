import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beeper/discord/connection.dart';
import 'package:beeper/discord/discord.dart';

class DiscordServerRequest {
  final DiscordServer server;
  final HttpRequest httpRequest;
  final List<String> path;
  final Map<String, String> args;

  DiscordServerRequest({
    required this.server,
    required this.httpRequest,
    required this.path,
    required this.args,
  });

  String? string(String key) {
    return args[key];
  }

  int integer(String key) {
    return int.parse(args[key]!);
  }

  static DiscordServerRequest? fromPath({
    required String pattern,
    required DiscordServer server,
    required HttpRequest httpRequest,
    required List<String> path,
  }) {
    final segments = pattern.split('/');
    final args = <String, String>{};

    if (path.length != segments.length) {
      return null;
    }

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.startsWith(':')) {
        args[segment.substring(1)] = path[i];
      } else if (segment != path[i]) {
        return null;
      }
    }

    return DiscordServerRequest(
      server: server,
      httpRequest: httpRequest,
      path: path,
      args: args,
    );
  }
}

final _upgraded = Object();
final matchers = <String, Future<dynamic> Function(DiscordServerRequest)>{
  'gateway/bot': (r) async {
    return {
      'shards': 1,
      'session_start_limit': {
        'total': 1000,
        'remaining': 1000,
        'reset_after': 86400000,
        'max_concurrency': 1,
      },
      'url': '${r.server.uri.replace(
        scheme: 'ws',
        path: 'gateway/ws',
      )}',
    };
  },
  'gateway/ws': (r) async {
    final socket = await WebSocketTransformer.upgrade(r.httpRequest);
    r.server.acceptClient(socket);
    return _upgraded;
  }
};

class DiscordServerHttpError {
  final int code;
  final String reason;

  DiscordServerHttpError(this.code, this.reason);

  @override
  String toString() => '$code $reason';
}

class DiscordServer {
  final Uri uri;
  final String validAuthorization;

  DiscordServer({
    required this.uri,
    required this.validAuthorization,
  });

  late HttpServer httpServer;

  final clients = <WebSocket>{};

  void acceptClient(WebSocket socket) async {
    var seq = 0;
    void send(int op, [dynamic data, String? name]) {
      final str = jsonEncode(<String, dynamic>{
        'op': op,
        if (data != null) 'd': data,
        if (op != Op.heartbeatAck) 's': seq++,
        if (name != null) 't': name,
      });
      print('Server sent $str');
      socket.add(str);
    }

    clients.add(socket);
    print('Accepted client $socket');

    send(Op.hello, {
      'heartbeat_interval': 500,
    });

    await for (final message in socket) {
      final dynamic data = jsonDecode(message as String);
      print('Server received $message');

      final op = data['op'] as int?;

      if (op == Op.heartbeat) {
        send(Op.heartbeatAck);
      } else if (op == Op.identify) {
        send(
          Op.dispatch,
          <String, dynamic>{
            'user': {
              'id': '${Snowflake.random()}',
              'username': 'test_bot',
              'discriminator': '1234',
              'bot': true,
            },
            'guilds': <dynamic>[],
          },
          'READY',
        );
      }
    }
    clients.remove(socket);
  }

  static bool isValidUserAgent(String? name) {
    if (name == null) {
      return false;
    }
    return RegExp(r'^.+ \(.+, .+\)$').hasMatch(name);
  }

  static bool requiresAuthorization(List<String> path) {
    final str = path.join('/');
    return str != 'gateway/ws';
  }

  Future<dynamic> _handle(HttpRequest request, List<String> path) {
    if (requiresAuthorization(path)) {
      if (request.headers.value('authorization') != validAuthorization) {
        throw DiscordServerHttpError(401, 'Unauthorized');
      } else if (!isValidUserAgent(request.headers.value('user-agent'))) {
        throw DiscordServerHttpError(400, 'Wrong user agent');
      }
    }

    for (final e in matchers.entries) {
      final req = DiscordServerRequest.fromPath(
        pattern: e.key,
        server: this,
        httpRequest: request,
        path: path,
      );

      if (req != null) {
        return e.value(req);
      }
    }

    stderr.writeln('Server Error: Endpoint "${path.join('/')}" not found');
    throw DiscordServerHttpError(404, 'Not Found');
  }

  List<String>? resolvePath(List<String> path) {
    if (uri.pathSegments.length > path.length) {
      return null;
    }

    for (var i = 0; i < uri.pathSegments.length; i++) {
      if (path[i] != uri.pathSegments[i]) {
        return null;
      }
    }

    return path.skip(uri.pathSegments.length).toList();
  }

  var _started = false;

  Future<void> start() async {
    assert(!_started);
    _started = true;
    httpServer = await HttpServer.bind(uri.host, uri.port);
    httpServer.forEach((request) async {
      final res = request.response;
      final path = resolvePath(
          request.requestedUri.pathSegments.where((e) => e != '').toList());
      if (path != null) {
        try {
          final Object? result = await _handle(request, path);
          if (result == _upgraded) {
            return;
          } else if (result != null) {
            res.headers.contentType = ContentType.json;
            res.write(jsonEncode(result));
            await res.close();
          }
        } catch (e) {
          if (e is DiscordServerHttpError) {
            res.statusCode = e.code;
            res.reasonPhrase = e.reason;
            await res.close();
          }
          rethrow;
        }
      }
    });
  }
}
