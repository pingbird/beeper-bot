import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart';
import 'package:beeper/modules/discord.dart';

@Metadata(name: 'ping')
class PingModule extends Module with DiscordLoader, CommandsLoader {
  final String response;

  PingModule({this.response});

  @Command(alias: {'p'})
  void ping(CommandInvocation cmd) {
    cmd.writeln('pong');
  }
}