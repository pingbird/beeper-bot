import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;

final moduleMetadata = {
  CommandsModule: Metadata(name: 'commands', factory: () => CommandsModule()),
  DiscordModule: Metadata(name: 'discord', factory: () => DiscordModule()),
};

mixin CommandsLoader on Module {
  CommandsModule commands;

  @override
  Future<void> load() async {
    await super.load();
    commands = await scope.require();
  }
}
