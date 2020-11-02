import 'package:beeper/modules.dart';
import 'package:beeper/modules/discord.dart';
import 'package:beeper/modules/disposer.dart';

@Metadata(name: 'commands')
class CommandsModule extends Module with Disposer, DiscordLoader {
  @override
  Future<void> load() async {
    await super.load();
    print('connected! ${discord.user.name}');
  }
}