import 'package:beeper/modules.dart';
import 'package:beeper/modules/admin.dart' show AdminModule;
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/database.dart' show DatabaseModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;
import 'package:beeper/modules/ping.dart' show PingModule;
import 'package:beeper/modules/status.dart' show StatusModule;

Map<Type, Metadata> get moduleMetadata => {
      AdminModule: Metadata(name: 'admin', lazyLoad: false, factory: (dynamic data) => AdminModule(uri: data['uri'] as String, assetPath: data['assetPath'] as String)),
      CommandsModule: Metadata(name: 'commands', lazyLoad: true, factory: (dynamic data) => CommandsModule()),
      DatabaseModule: Metadata(name: 'database', lazyLoad: false, factory: (dynamic data) => DatabaseModule(uri: data['uri'] as String)),
      DiscordModule: Metadata(name: 'discord', lazyLoad: false, factory: (dynamic data) => DiscordModule(token: data['token'] as String)),
      PingModule: Metadata(name: 'ping', lazyLoad: false, factory: (dynamic data) => PingModule(response: data['response'] as String)),
      StatusModule: Metadata(name: 'status', lazyLoad: true, factory: (dynamic data) => StatusModule()),
    };

mixin CommandsLoader on Module {
  CommandsModule commands;

  @override
  Future<void> load() async {
    await super.load();
    commands = await scope.require();
  }
}

mixin DatabaseLoader on Module {
  DatabaseModule database;

  @override
  Future<void> load() async {
    await super.load();
    database = await scope.require();
  }
}
