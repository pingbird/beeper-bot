import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart' show CommandsModule;
import 'package:beeper/modules/discord.dart' show DiscordModule;
final moduleMetadata = {
CommandsModule: ModuleMetadata(label:'commands',factory: () => CommandsModule()),
DiscordModule: ModuleMetadata(label:'discord_loader',factory: () => DiscordModule()),
};
