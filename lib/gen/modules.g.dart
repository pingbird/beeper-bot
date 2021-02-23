import 'package:beeper/modules.dart';
import 'package:beeper/modules/discord/history.dart' show DiscordHistoryModule;
import 'package:beeper/modules/status.dart' show StatusModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;
import 'package:beeper/modules/ping.dart' show PingModule;
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/admin.dart' show AdminModule;
import 'package:beeper/modules/database.dart' show DatabaseModule;

Map<Type, Metadata> get moduleMetadata => {
      DiscordHistoryModule: Metadata(name: 'discord_history', lazyLoad: true, factory: (dynamic data) => DiscordHistoryModule()),
      StatusModule: Metadata(name: 'status', lazyLoad: false, factory: null),
      DiscordModule: Metadata(name: 'discord', lazyLoad: true, factory: (dynamic data) => DiscordModule(token: data['token'] as String, endpoint: data['endpoint'] as String)),
      PingModule: Metadata(name: 'ping', lazyLoad: true, factory: (dynamic data) => PingModule(response: data['response'] as String)),
      CommandsModule: Metadata(name: 'commands', lazyLoad: true, factory: (dynamic data) => CommandsModule()),
      AdminModule: Metadata(name: 'admin', lazyLoad: true, factory: (dynamic data) => AdminModule(uri: data['uri'] as String, assetPath: data['assetPath'] as String)),
      DatabaseModule: Metadata(name: 'database', lazyLoad: true, factory: (dynamic data) => DatabaseModule(host: data['host'] as String, port: data['port'] as int, user: data['user'] as String, password: data['password'] as String, database: data['database'] as String)),
    };
