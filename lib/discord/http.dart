import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

class DiscordHttpError {
  final http.BaseRequest/*!*/ request;
  final http.BaseResponse/*!*/ response;

  DiscordHttpError({
    final this.request,
    final this.response,
  });

  @override
  String toString() {
    return 'Discord HTTP request failed: ${request.method} ${request.url} '
        'returned ${response.statusCode}';
  }
}

class HttpService {
  final client = http.Client();

  final Uri endpoint;
  final String/*!*/ authorization;
  final String/*!*/ userAgent;

  final buckets = <String, HttpBucket>{};

  HttpService({
    @required this.endpoint,
    this.authorization,
    this.userAgent,
  });

  Future<http.StreamedResponse> sendRaw(http.BaseRequest request) async {
    var bucket = buckets[request.url.path];
    if (bucket == null) {
      bucket = HttpBucket();
      buckets[request.url.path] = bucket;
    }

    return bucket.wrap(() async {
      request.headers['authorization'] ??= authorization;
      request.headers['user-agent'] ??= userAgent;

      final response = await client.send(request);

      final time = DateTime.now();

      int remaining;
      if (response.headers.containsKey('x-ratelimit-remaining')) {
        remaining = int.parse(response.headers['x-ratelimit-remaining']);
      }

      DateTime resetAt;
      if (response.headers.containsKey('x-ratelimit-reset-after')) {
        final dt = double.parse(response.headers['x-ratelimit-reset-after']);
        resetAt = time.add(
          Duration(milliseconds: (dt * 1000).round()),
        );
      }

      bucket.queueReset(
        remaining: remaining,
        resetAt: resetAt,
      );

      return response;
    });
  }

  Future<dynamic> send(
    String method,
    String path, {
    Map<String, dynamic> queryParameters,
    dynamic body,
  }) async {
    final request = http.Request(
      method,
      endpoint.replace(
        path: endpoint.path + '/' + path,
        queryParameters: queryParameters == null
            ? null
            : <String, dynamic>{
                for (var e in queryParameters.entries)
                  if (e.value is Iterable)
                    e.key: e.value.map((Object v) => '$v')
                  else
                    e.key: '${e.value}',
              },
      ),
    );

    if (body != null) {
      request.body = jsonEncode(body);
      request.headers['Content-Type'] = 'application/json';
    }

    final response = await sendRaw(request);
    if (response.statusCode ~/ 100 != 2) {
      throw DiscordHttpError(request: request, response: response);
    }
    return jsonDecode(await response.stream.bytesToString());
  }

  Future<dynamic> get(String path, {Map<String, dynamic> queryParameters}) =>
      send('GET', path, queryParameters: queryParameters);

  Future<dynamic> post(
    String path, {
    Map<String, dynamic> queryParameters,
    dynamic body,
  }) =>
      send('POST', path, queryParameters: queryParameters, body: body);
}

class HttpBucket {
  final _queue = Queue<Completer<void>>();
  int remaining = 1;
  int active = 0;
  int get available => remaining - active;
  DateTime resetAt = DateTime.fromMicrosecondsSinceEpoch(0);
  Timer reset;

  Future<T> wrap<T>(Future<T> Function() fn) async {
    final nextReset = resetAt;
    if (available > 0) {
      active++;
    } else {
      final completer = Completer<void>();
      _queue.add(completer);
      await completer.future;
    }

    try {
      return fn();
    } finally {
      if (nextReset != null && !resetAt.isAfter(nextReset)) {
        // Don't take away from remaining if the reset elapsed
        remaining--;
      }
      active--;
    }
  }

  void _reset() {
    while (_queue.isNotEmpty && available != 0) {
      active++;
      _queue.removeFirst().complete();
    }
  }

  void queueReset({
    @required int remaining,
    @required DateTime resetAt,
  }) {
    remaining ??= this.remaining ?? 10;
    resetAt ??= this.resetAt ?? DateTime.now().add(const Duration(seconds: 1));

    if (!resetAt.isAfter(this.resetAt)) {
      this.remaining = min(this.remaining, remaining);
    } else {
      this.remaining = remaining;
    }
    this.resetAt = resetAt;
    reset?.cancel();
    reset = Timer(DateTime.now().difference(resetAt), _reset);
  }
}
