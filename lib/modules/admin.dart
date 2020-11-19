import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:beeper/modules/status.dart';
import 'package:meta/meta.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:pedantic/pedantic.dart';

import 'package:beeper/beeper.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules/disposer.dart';

DateTime startTime;

class AdminClient {
  WebSocket socket;

  AdminClient({
    @required this.socket,
  });

  void send(dynamic data) {
    socket.add(jsonEncode(data));
  }
}

@Metadata(name: 'admin')
class AdminModule extends Module with StatusLoader, Disposer {
  final Uri uri;
  final String assetPath;

  AdminModule({
    @required String uri,
    @required this.assetPath,
  }) : uri = Uri.parse('//$uri');

  HttpServer server;
  Handler staticHandler;

  Future<void> _handleStatic(HttpRequest client) async {
    return handleRequest(client, (client) {
      return staticHandler(client);
    });
  }

  Future<void> _handleError(HttpRequest request, [int code = 500, String text]) async {
    final res = request.response;
    res.headers.contentType = ContentType.html;
    res.statusCode = code;
    res.writeln('<h1>Error $code</h1>');
    if (text != null) {
      res.writeln('<pre>${htmlEscape.convert(text)}</pre>');
    }
    await res.flush();
    await res.close();
  }

  final clients = <AdminClient>{};

  void sendAll(dynamic data) {
    for (final client in clients) {
      client.send(data);
    }
  }

  final statuses = <String, dynamic>{};

  Future<void> _handleWebsocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    unawaited(() async {
      final client = AdminClient(socket: socket);
      try {
        client.send({
          't': 'status',
          'd': {
            'version': bot.version,
            'started': startTime.millisecondsSinceEpoch,
            'statuses': statuses,
          },
        });
        clients.add(client);
        await for (final message in socket) {
          // TODO(ping): Do console stuff
          final dynamic data = jsonDecode(message as String);
          print(data);
        }
      } catch(e, bt) {
        // TODO(ping): Logging framework
        Zone.current.errorCallback(e, bt);
      } finally {
        clients.remove(client);
        await client.socket.close();
      }
    }());
  }

  @override
  Future<void> load() async {
    await super.load();

    startTime ??= DateTime.now();

    server = await HttpServer.bind(uri.host, uri.port);
    staticHandler = createStaticHandler(assetPath, defaultDocument: 'index.html');
    queueDispose(server.listen((client) async {
      try {
        if (client.uri.path == '/ws') {
          await _handleWebsocket(client);
        } else {
          await _handleStatic(client);
        }
      } catch (e, bt) {
        await _handleError(client, 500, '$e\n$bt');
      }
    }));

    print('Admin interface listening on $uri');

    queueDispose(statusModule.updates.listen((event) {
      final name = event.module.canonicalName;
      if (event.data == null) {
        statuses.remove(event.module.canonicalName);
      } else {
        statuses[name] = event.data;
      }
      sendAll(<String, dynamic>{
        't': 'status_update',
        'm': name,
        'd': event.data,
      });
    }));
  }

  @override
  Future<void> unload() async {
    await super.unload();
    statuses.clear();
  }
}