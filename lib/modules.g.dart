import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart' show CommandsMod;
import 'package:beeper/modules/discord.dart' show DiscordModule;

final moduleMetadata = {
  CommandsMod: ModuleMetadata(label: 'commands', factory: () => CommandsMod()),
  DiscordModule:
      ModuleMetadata(label: 'discord_loader', factory: () => DiscordModule()),
};
