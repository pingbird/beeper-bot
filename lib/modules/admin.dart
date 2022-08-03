import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:beeper/beeper.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules/disposer.dart';
import 'package:beeper/modules/status.dart';
import 'package:beeper_common/logging.dart';
import 'package:path/path.dart' as path;
import 'package:pedantic/pedantic.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_proxy/shelf_proxy.dart';

DateTime? startTime;

class AdminClient {
  WebSocket socket;

  AdminClient({
    required this.socket,
  });

  void send(dynamic data) {
    socket.add(jsonEncode(data));
  }
}

@Metadata(name: 'admin')
class AdminModule extends Module with StatusLoader, Disposer {
  final Uri uri;
  final bool development;
  final int adminPort;
  final int webdevPort;

  AdminModule({
    required String uri,
    bool? development,
    int? adminPort,
    int? webdevPort,
  })  : uri = Uri.parse(uri),
        development = development ?? false,
        adminPort = adminPort ?? 4050,
        webdevPort = webdevPort ?? 4051;

  static const maxLogHistory = 4096;
  final logHistory = Queue<LogEvent>();

  late HttpServer server;

  Process? webdevProcess;

  Future<void> _handleError(HttpRequest request,
      [int code = 500, String? text]) async {
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
    final str = jsonEncode(data);
    for (final client in clients) {
      client.socket.add(str);
    }
  }

  var statuses = <String, dynamic>{};

  Future<void> _handleWebsocket(HttpRequest request) async {
    final socket = await WebSocketTransformer.upgrade(request);
    unawaited(() async {
      final client = AdminClient(socket: socket);
      try {
        client.send({
          't': 'status',
          'd': {
            'version': bot.version,
            'started': startTime!.millisecondsSinceEpoch,
            'statuses': statuses,
            'logs': logHistory.toList(),
          },
        });
        clients.add(client);
        await for (final message in socket) {
          // TODO(ping): Do console stuff
          final dynamic data = jsonDecode(message as String);
          print(data);
        }
      } catch (e, bt) {
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
    server = await HttpServer.bind('127.0.0.1', adminPort);
    log('Listening on $adminPort');
    log('Visit at $uri');

    if (development) {
      log('Starting webdev');

      webdevProcess = await Process.start(
        'flutter',
        ['run', '-d', 'web-server', '--web-port=$webdevPort'],
        workingDirectory: path.join(Directory.current.path, 'admin2'),
        runInShell: true,
      );

      const LineSplitter()
          .bind(utf8.decoder.bind(webdevProcess!.stdout))
          .listen((event) {
        if (!event.startsWith('[INFO]') && event != '\x1b[2K') {
          log('webdev: $event');
        }
      });

      const LineSplitter()
          .bind(utf8.decoder.bind(webdevProcess!.stderr))
          .listen((event) => log('webdev: $event', level: LogLevel.warning));

      webdevProcess!.exitCode.then((exitCode) {
        log(
          'webdev exited with status code $exitCode',
          level: LogLevel.warning,
        );
      });
    }

    queueDispose(server.listen((client) async {
      try {
        if (client.uri.path == '/ws') {
          await _handleWebsocket(client);
        } else if (development) {
          await handleRequest(
            client,
            proxyHandler('http://localhost:$webdevPort'),
          );
        } else {
          await _handleError(
            client,
            404,
            'Forgot to configure nginx?',
          );
        }
      } catch (e, bt) {
        await _handleError(client, 500, '$e\n$bt');
      }
    }));

    statuses = statusModule.getStatuses();
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

    queueDispose(statusModule.events.listen((event) {
      if (logHistory.length >= maxLogHistory) {
        logHistory.removeFirst();
      }
      logHistory.add(event);
      sendAll({
        't': 'log',
        'd': event,
      });
    }));
  }

  @override
  Future<void> unload() async {
    webdevProcess?.kill();
    statuses.clear();
    await super.unload();
  }
}
