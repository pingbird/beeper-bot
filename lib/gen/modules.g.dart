// ignore_for_file: directives_ordering, prefer_const_constructors
import 'package:beeper/modules.dart';
import 'package:beeper/modules/admin.dart' show AdminModule;
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/database.dart' show DatabaseModule;
import 'package:beeper/modules/discord/history.dart' show DiscordHistoryModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;
import 'package:beeper/modules/hot_reload.dart' show HotReloadModule;
import 'package:beeper/modules/ping.dart' show PingModule;
import 'package:beeper/modules/status.dart' show StatusModule;

Map<Type, Metadata> get moduleMetadata => {
      AdminModule: Metadata(
          name: 'admin',
          lazyLoad: true,
          factory: (dynamic data) => AdminModule(
              uri: data['uri'] as String,
              development: data['development'] as bool?,
              adminPort: data['adminPort'] as int?,
              webdevPort: data['webdevPort'] as int?)),
      CommandsModule: Metadata(
          name: 'commands',
          lazyLoad: true,
          factory: (dynamic data) => CommandsModule()),
      DatabaseModule: Metadata(
          name: 'database',
          lazyLoad: true,
          factory: (dynamic data) => DatabaseModule(
              host: data['host'] as String,
              port: data['port'] as int,
              user: data['user'] as String,
              password: data['password'] as String,
              database: data['database'] as String)),
      DiscordHistoryModule: Metadata(
          name: 'discord_history',
          lazyLoad: true,
          factory: (dynamic data) => DiscordHistoryModule()),
      DiscordModule: Metadata(
          name: 'discord',
          lazyLoad: true,
          factory: (dynamic data) => DiscordModule(
              token: data['token'] as String,
              endpoint: data['endpoint'] as String?)),
      HotReloadModule: Metadata(
          name: 'hot_reload',
          lazyLoad: true,
          factory: (dynamic data) => HotReloadModule()),
      PingModule: Metadata(
          name: 'ping',
          lazyLoad: true,
          factory: (dynamic data) =>
              PingModule(response: data['response'] as String?)),
      StatusModule: Metadata(name: 'status', lazyLoad: false, factory: null),
    };
