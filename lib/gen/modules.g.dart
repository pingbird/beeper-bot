import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;
import 'package:beeper/modules/ping.dart' show PingModule;

final moduleMetadata = {
  CommandsModule: Metadata(name: 'commands', lazyLoad: true, factory: (dynamic data) => CommandsModule()),
  DiscordModule: Metadata(name: 'discord', lazyLoad: false, factory: (dynamic data) => DiscordModule(token: data['token'] as String)),
  PingModule: Metadata(name: 'ping', lazyLoad: true, factory: (dynamic data) => PingModule()),
};

mixin CommandsLoader on Module {
  CommandsModule commands;

  @override
  Future<void> load() async {
    await super.load();
    commands = await scope.require();
  }
}

mixin PingLoader on Module {
  PingModule ping;

  @override
  Future<void> load() async {
    await super.load();
    ping = await scope.require();
  }
}
