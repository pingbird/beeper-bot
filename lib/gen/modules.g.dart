import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/database.dart' show DatabaseModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;
import 'package:beeper/modules/ping.dart' show PingModule;

Map<Type, Metadata> get moduleMetadata => {
      CommandsModule: Metadata(name: 'commands', lazyLoad: true, factory: (dynamic data) => CommandsModule()),
      DatabaseModule: Metadata(name: 'database', lazyLoad: false, factory: (dynamic data) => DatabaseModule(uri: data['uri'] as String)),
      DiscordModule: Metadata(name: 'discord', lazyLoad: false, factory: (dynamic data) => DiscordModule(token: data['token'] as String)),
      PingModule: Metadata(name: 'ping', lazyLoad: false, factory: (dynamic data) => PingModule(response: data['response'] as String)),
    };

mixin CommandsLoader on Module {
  CommandsModule commands;

  @override
  Future<void> load() async {
    await super.load();
    commands = await scope.require();
  }
}
