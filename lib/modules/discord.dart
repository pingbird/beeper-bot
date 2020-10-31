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

class DiscordModule extends Module {
  static const label = 'discord_loader';
  Discord discord;

  @override
  Future<void> load() async {
    await super.load();
    assert(config != null, 'Config required for discord_loader');
    final token = config['token'] as String;
    assert(token != null, 'Config missing token for discord_loader');
    discord = Discord(token: token);
    await discord.start();
    await for (final state in discord.connectionStates) {
      if (state.isConnected) break;
    }
  }
}