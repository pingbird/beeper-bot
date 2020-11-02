import 'package:meta/meta.dart';

import 'package:beeper/discord/discord.dart';
import 'package:beeper/modules.dart';

mixin DiscordLoader on Module {
  Discord discord;

  @override
  Future<void> load() async {
    await super.load();
    discord = (await scope.require<DiscordModule>()).discord;
  }
}

@Metadata(name: 'discord')
class DiscordModule extends Module {
  Discord discord;

  final String token;

  DiscordModule({
    @required this.token,
  });

  @override
  Future<void> load() async {
    await super.load();
    discord = Discord(token: token);
    await discord.start();
    await for (final state in discord.connectionStates) {
      if (state.isConnected) break;
    }
  }
}