import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';

extension ShelfRequestExtensions on Request {
  Request copyWith({
    String? method,
    Uri? requestedUri,
    String? protocolVersion,
    Map<String, /* String | List<String> */ Object>? headers,
    String? handlerPath,
    Uri? url,
    Object? body,
    Encoding? encoding,
    Map<String, Object>? context,
  }) {
    return Request(
      method ?? this.method,
      requestedUri ?? this.requestedUri,
      protocolVersion: protocolVersion ?? this.protocolVersion,
      headers: headers ?? this.headers,
      handlerPath: handlerPath ?? this.handlerPath,
      url: url ?? this.url,
      body: body ?? read(),
      encoding: encoding ?? this.encoding,
      context: context ?? this.context,
    );
  }
}

Handler proxyHandler(
  Object url, {
  String? prefix,
  http.Client? client,
  String? proxyName,
}) {
  Uri uri;
  if (url is String) {
    uri = Uri.parse(url);
  } else if (url is Uri) {
    uri = url;
  } else {
    throw ArgumentError.value(url, 'url', 'url must be a String or Uri.');
  }
  final nonNullClient = client ?? http.Client();
  proxyName ??= 'shelf_proxy';

  return (serverRequest) async {
    final requestUrl = uri.resolve(serverRequest.url.toString());
    final clientRequest = http.StreamedRequest(serverRequest.method, requestUrl)
      ..followRedirects = false
      ..headers.addAll(serverRequest.headers)
      ..headers['Host'] = uri.authority;

    _addHeader(clientRequest.headers, 'via',
        '${serverRequest.protocolVersion} $proxyName');

    serverRequest
        .read()
        .forEach(clientRequest.sink.add)
        .catchError(clientRequest.sink.addError)
        .whenComplete(clientRequest.sink.close)
        .ignore();
    final clientResponse = await nonNullClient.send(clientRequest);

    _addHeader(clientResponse.headers, 'via', '1.1 $proxyName');

    clientResponse.headers.remove('transfer-encoding');

    if (clientResponse.headers['content-encoding'] == 'gzip') {
      clientResponse.headers.remove('content-encoding');
      clientResponse.headers.remove('content-length');

      _addHeader(
        clientResponse.headers,
        'warning',
        '214 $proxyName "GZIP decoded"',
      );
    }

    if (clientResponse.isRedirect &&
        clientResponse.headers.containsKey('location')) {
      final location = requestUrl
          .resolve(
            clientResponse.headers['location']!,
          )
          .toString();
      if (p.url.isWithin(uri.toString(), location)) {
        clientResponse.headers['location'] =
            '/${p.url.relative(location, from: uri.toString())}';
      } else {
        clientResponse.headers['location'] = location;
      }
    }

    return Response(clientResponse.statusCode,
        body: clientResponse.stream, headers: clientResponse.headers);
  };
}

// TODO(nweiz): use built-in methods for this when http and shelf support them.
/// Add a header with [name] and [value] to [headers], handling existing headers
/// gracefully.
void _addHeader(Map<String, String> headers, String name, String value) {
  final existing = headers[name];
  headers[name] = existing == null ? value : '$existing, $value';
}
