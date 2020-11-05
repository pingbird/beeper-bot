import 'package:beeper/modules.dart';
import 'package:beeper/modules/discord.dart';
import 'package:beeper/modules/disposer.dart';

class Command {
  final String name;
  final Set<String> alias;

  const Command({
    this.name,
    this.alias = const {},
  });
}

@Metadata(name: 'commands')
class CommandsModule extends Module with Disposer, DiscordLoader {
  @override
  Future<void> load() async {
    await super.load();
    print('connected! ${discord.user.name}');
  }
}