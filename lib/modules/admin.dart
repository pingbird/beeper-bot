import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

import 'package:beeper/modules.dart';
import 'package:beeper/modules/disposer.dart';

@Metadata(name: 'admin')
class AdminModule extends Module with DatabaseLoader, Disposer {
  final Uri uri;
  final String assetPath;

  AdminModule({
    @required String uri,
    @required this.assetPath,
  }) : uri = Uri.parse('//$uri');

  HttpServer server;
  Handler staticHandler;

  Future<void> _handleClient(HttpRequest client) async {
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

  @override
  Future<void> load() async {
    await super.load();
    server = await HttpServer.bind(uri.host, uri.port);
    staticHandler = createStaticHandler(assetPath, defaultDocument: 'index.html');
    queueDispose(server.listen((client) async {
      try {
        await _handleClient(client);
      } catch (e, bt) {
        await _handleError(client, 500, '$e\n$bt');
      }
    }));
    print('Admin interface listening on $uri');
  }
}