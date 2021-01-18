import 'package:beeper/modules.dart';
import 'package:beeper/modules/status.dart' show StatusModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;
import 'package:beeper/modules/ping.dart' show PingModule;
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/admin.dart' show AdminModule;
import 'package:beeper/modules/database.dart' show DatabaseModule;

Map<Type, Metadata> get moduleMetadata => {
      StatusModule: Metadata(name: 'status', lazyLoad: true, factory: (dynamic data) => StatusModule()),
      DiscordModule: Metadata(name: 'discord', lazyLoad: false, factory: (dynamic data) => DiscordModule(token: data['token'] as String, endpoint: data['endpoint'] as String)),
      PingModule: Metadata(name: 'ping', lazyLoad: false, factory: (dynamic data) => PingModule(response: data['response'] as String)),
      CommandsModule: Metadata(name: 'commands', lazyLoad: true, factory: (dynamic data) => CommandsModule()),
      AdminModule: Metadata(name: 'admin', lazyLoad: false, factory: (dynamic data) => AdminModule(uri: data['uri'] as String, assetPath: data['assetPath'] as String)),
      DatabaseModule: Metadata(name: 'database', lazyLoad: false, factory: (dynamic data) => DatabaseModule(host: data['host'] as String, port: data['port'] as int, user: data['user'] as String, password: data['password'] as String, database: data['database'] as String)),
    };

mixin DatabaseLoader on Module {
  DatabaseModule database;

  @override
  Future<void> load() async {
    await super.load();
    database = await scope.require();
  }
}
