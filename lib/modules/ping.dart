import 'package:beeper/gen/modules.g.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart';
import 'package:beeper/modules/discord.dart';

@Metadata(name: 'ping')
class PingModule extends Module with DiscordLoader, CommandsLoader {
  @Command()
  String ping() => 'pong';
}