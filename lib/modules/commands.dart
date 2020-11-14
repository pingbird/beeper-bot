import 'package:meta/meta.dart';

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

class CommandEntry<T extends Module> {
  Type get moduleType => T;
  Command metadata;
  Function Function(T module) extractor;

  CommandEntry({
    @required this.metadata,
    @required this.extractor,
  });
}

@Metadata(name: 'commands', loadable: true)
class CommandsModule extends Module with Disposer, DiscordLoader {
  @override
  Future<void> load() async {
    await super.load();
    print('connected! ${discord.user.name}');
  }
}