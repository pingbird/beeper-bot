import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' hide HttpException;
import 'dart:math' hide log;

import 'package:beeper/beeper.dart';
import 'package:beeper/common/shelf.dart';
import 'package:beeper/discord/state.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules/database.dart';
import 'package:beeper/modules/discord.dart';
import 'package:beeper/modules/disposer.dart';
import 'package:beeper/modules/status.dart';
import 'package:beeper_common/admin.dart';
import 'package:beeper_common/debouncer.dart';
import 'package:beeper_common/logging.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:pedantic/pedantic.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:watcher/watcher.dart';

import '../common/http.dart';

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

class AdminSessionState {
  final DateTime expires;
  final String? discordAccessToken;
  final String? discordRefreshToken;

  AdminSessionState({
    required this.expires,
    required this.discordAccessToken,
    required this.discordRefreshToken,
  });
}

@Metadata(name: 'admin')
class AdminModule extends Module with StatusLoader, DatabaseLoader, Disposer {
  final Uri uri;
  final bool development;
  final int adminPort;
  final int webdevPort;
  final String? oauthClientId;
  final String? oauthSecret;

  AdminModule({
    required String uri,
    bool? development,
    int? adminPort,
    int? webdevPort,
    this.oauthClientId,
    this.oauthSecret,
  })  : uri = Uri.parse(uri),
        development = development ?? false,
        adminPort = adminPort ?? 4050,
        webdevPort = webdevPort ?? 4051;

  static const maxLogHistory = 4096;
  final logHistory = Queue<LogEvent>();

  late HttpServer server;

  StreamSubscription? consoleWatcher;
  Process? webdevProcess;

  Future<void> _handleJson(
    HttpRequest request,
    dynamic body, [
    int code = 200,
  ]) async {
    final res = request.response;
    res.headers.contentType = ContentType.json;
    res.statusCode = code;
    res.write(jsonEncode(body));
    await res.flush();
    await res.close();
  }

  Future<void> _handleError(
    HttpRequest request, [
    int code = 500,
    String? text,
  ]) async {
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

  Future<void> _handleRedirect(
    HttpRequest req,
    Uri uri,
  ) async {
    final res = req.response;
    res.statusCode = 302;
    res.headers.add('Location', '$uri');
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

  Future<String> createSession() async {
    final rand = Random.secure();
    final token = List.generate(16, (_) => rand.nextInt(256))
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();
    final expires = DateTime.now().add(const Duration(days: 7));
    await database.con.execute(
      '''
      insert into AdminSessions (Token, Expires) values (@Token, @Expires)
    ''',
      substitutionValues: <String, dynamic>{
        'Token': token,
        'Expires': expires,
      },
    );
    return token;
  }

  Future<void> updateSessionTokens({
    required String token,
    required String discordAccessToken,
    required String discordRefreshToken,
    required DateTime expires,
  }) async {
    await database.con.execute(
      '''
      update AdminSessions
      set
        DiscordAccessToken=@DiscordAccessToken,
        DiscordRefreshToken=@DiscordRefreshToken,
        Expires=@Expires
      where Token = @Token
    ''',
      substitutionValues: <String, dynamic>{
        'DiscordAccessToken': discordAccessToken,
        'DiscordRefreshToken': discordRefreshToken,
        'Expires': expires,
        'Token': token,
      },
    );
  }

  Future<bool> deleteSession(String token) async {
    final result = await database.con.execute(
      '''
      delete from AdminSessions where Token = @Token
    ''',
      substitutionValues: <String, dynamic>{'Token': token},
    );
    return result != 0;
  }

  Future<AdminSessionState?> getSessionState(String token) async {
    final result = await database.con.query(
      '''
      select * from AdminSessions where Token = @Token
    ''',
      substitutionValues: <String, dynamic>{'Token': token},
    );
    if (result.isEmpty) {
      return null;
    }
    final row = result.single.toColumnMap();
    final expires = row['expires'] as DateTime;
    if (DateTime.now().isAfter(expires)) {
      await deleteSession(token);
      return null;
    }
    return AdminSessionState(
      expires: expires,
      discordAccessToken: row['discordaccesstoken'] as String?,
      discordRefreshToken: row['discordrefreshtoken'] as String?,
    );
  }

  late final discord = scope.get<DiscordModule>()!.discord;
  late final discordUserAgent = discord.connection.http.userAgent;
  late final discordBaseUri = discord.connection.http.endpoint;

  Future<LoginStateDto> getLoginState(String? token) async {
    if (token == null) return LoginStateDto(signedIn: false);
    final sessionState = await getSessionState(token);
    if (sessionState == null) return LoginStateDto(signedIn: false);
    final identityResponse = await http.get(
      discordBaseUri.append(path: 'users/@me'),
      headers: {
        'authorization': 'Bearer ${sessionState.discordAccessToken}',
        'user-agent': discordUserAgent,
      },
    );
    HttpException.ensureSuccessRaw(identityResponse);
    final user = discord.updateUserEntity(jsonDecode(identityResponse.body));
    return LoginStateDto(
      signedIn: true,
      name: user.name,
      discriminator: user.discriminator,
      avatar: '${user.avatar(size: 64)}',
    );
  }

  static String? tokenFromRequest(HttpRequest req) {
    final cookies = req.headers['Cookie'];
    if (cookies == null || cookies.isEmpty) return null;
    for (final cookie
        in cookies.single.split(';').map(Cookie.fromSetCookieValue)) {
      if (cookie.name == 'beeper_session') {
        return cookie.value;
      }
    }
    return null;
  }

  late final authorizeUri = Uri(
    scheme: 'https',
    host: 'discord.com',
    path: 'api/oauth2/authorize',
    queryParameters: <String, String>{
      'client_id': oauthClientId!,
      'redirect_uri': '$uri/oauth2/redirect',
      'response_type': 'code',
      'scope': 'identify',
    },
  );

  void _handleRequest(HttpRequest req) async {
    if (development) {
      req.response.headers.add(
        HttpHeaders.accessControlAllowOriginHeader,
        '*',
      );
    }
    try {
      final path = req.uri.path;
      final pathSegments = req.uri.pathSegments;
      if (path == '/ws') {
        await _handleWebsocket(req);
      } else if (path == '/sign_in') {
        if (req.method != 'GET') return _handleError(req, 405);
        // Create session
        var token = tokenFromRequest(req);
        if (token != null) {
          await deleteSession(token);
        }
        token = await createSession();
        req.response.headers.add(
          'Set-Cookie',
          [
            'beeper_session=$token',
            if (development) 'SameSite=Lax' else 'SameSite=Strict',
            if (!development) 'Secure',
          ].join(';'),
        );

        if (oauthClientId == null) {
          return _handleError(req, 500, 'Missing oauthClientId');
        } else if (oauthSecret == null) {
          return _handleError(req, 500, 'Missing oauthSecret');
        }
        _handleRedirect(req, authorizeUri);
      } else if (path == '/sign_out') {
        if (req.method != 'GET') return _handleError(req, 405);
        final token = tokenFromRequest(req);
        if (token != null) {
          await deleteSession(token);
        }
        _handleRedirect(req, uri.append(path: 'console/'));
      } else if (path == '/state') {
        if (req.method != 'GET') return _handleError(req, 405);
        final token = tokenFromRequest(req);
        _handleJson(req, await getLoginState(token));
      } else if (path == '/oauth2/redirect') {
        if (req.method != 'GET') return _handleError(req, 405);
        final token = tokenFromRequest(req);
        if (token == null) {
          return _handleError(req, 400, 'No session');
        }
        if (req.method != 'GET') return _handleError(req, 405);
        final tokenResponse = await http.post(
          Uri.parse('https://discord.com/api/v9/oauth2/token'),
          body: <String, String>{
            'client_id': oauthClientId!,
            'client_secret': oauthSecret!,
            'grant_type': 'authorization_code',
            'code': req.uri.queryParameters['code']!,
            'redirect_uri': '$uri/oauth2/redirect',
          },
        );
        HttpException.ensureSuccessRaw(tokenResponse);
        final dynamic tokenBody = jsonDecode(tokenResponse.body);
        final expires = DateTime.now()
            .add(Duration(seconds: tokenBody['expires_in'] as int));
        await updateSessionTokens(
          token: token,
          discordAccessToken: tokenBody['access_token'] as String,
          discordRefreshToken: tokenBody['access_token'] as String,
          expires: expires,
        );
        _handleRedirect(req, uri.append(path: 'console/'));
      } else if (development) {
        if (pathSegments.isNotEmpty && pathSegments.first == 'console') {
          await handleRequest(
            req,
            (e) => proxyHandler('http://localhost:$webdevPort')(
              e.change(path: 'console'),
            ),
          );
        } else {
          await handleRequest(
            req,
            createStaticHandler(
              'www',
              defaultDocument: 'index.html',
            ),
          );
        }
      } else {
        await _handleError(
          req,
          404,
          'Forgot to configure nginx?',
        );
      }
    } catch (e, bt) {
      await _handleError(req, 500, '$e\n$bt');
    }
  }

  @override
  Future<void> load() async {
    await super.load();

    startTime ??= DateTime.now();
    server = await HttpServer.bind('127.0.0.1', adminPort);
    log('Listening on $adminPort');
    log('Visit at $uri');

    if (development) {
      bool startWebServer;
      try {
        final socket = await Socket.connect('localhost', webdevPort);
        socket.close();
        startWebServer = false;
      } on SocketException catch (_) {
        startWebServer = true;
      }

      if (startWebServer) {
        webdevProcess = await Process.start(
          'flutter',
          ['run', '-d', 'web-server', '--web-port=$webdevPort'],
          workingDirectory: path.join(Directory.current.path, 'console'),
          runInShell: true,
        );

        void hotReload() => webdevProcess?.stdin.writeln('R');

        final consoleDir = path.join(Directory.current.path, 'console');
        final reloadDebouncer = Debouncer(
          minDuration: const Duration(seconds: 1),
          onUpdate: (_) => hotReload(),
        );
        consoleWatcher = Watcher(consoleDir).events.listen((ev) {
          final relativePath = path.relative(ev.path, from: consoleDir);
          final segments = path.split(relativePath);
          if (segments.length > 1 &&
              const [
                'lib',
                'assets',
                'web',
              ].contains(segments.first)) {
            reloadDebouncer.add(null);
          }
        });

        const LineSplitter()
            .bind(utf8.decoder.bind(webdevProcess!.stdout))
            .listen((event) {
          if (!event.startsWith('[INFO]') && event != '\x1b[2K') {
            if (development && event.startsWith('Restarted application in')) {
              sendAll({
                't': 'reload',
              });
            }
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
    }

    queueDispose(server.listen(_handleRequest));

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
    consoleWatcher?.cancel();
    consoleWatcher = null;
    webdevProcess?.kill();
    webdevProcess = null;
    statuses.clear();
    await super.unload();
  }

  @override
  Iterable<dynamic> get dbSetup => const <String>[
        '''
      create table AdminSessions (
        Id serial primary key,
        Token text unique not null,
        Expires timestamp not null,
        DiscordAccessToken text,
        DiscordRefreshToken text
      );
    ''',
      ];
}
