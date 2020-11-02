import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;

final moduleMetadata = {
  CommandsModule: Metadata(name: 'commands', lazyLoad: true, factory: (dynamic data) => CommandsModule()),
  DiscordModule: Metadata(name: 'discord', lazyLoad: false, factory: (dynamic data) => DiscordModule(token: data['token'] as String)),
};

mixin CommandsLoader on Module {
  CommandsModule commands;

  @override
  Future<void> load() async {
    await super.load();
    commands = await scope.require();
  }
}
