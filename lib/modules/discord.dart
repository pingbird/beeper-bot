import 'package:beeper/discord/discord.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules/status.dart';
import 'package:beeper/secrets.dart';
import 'package:meta/meta.dart';

mixin DiscordLoader on Module {
  Discord/*!*/ discord;

  @override
  Future<void> load() async {
    await super.load();
    discord = (await scope.require<DiscordModule>()).discord;
  }
}

@Metadata(name: 'discord')
class DiscordModule extends Module with StatusLoader {
  Discord/*!*/ discord;

  final String/*!*/ token;
  final String endpoint;

  DiscordModule({
    @required this.token,
    this.endpoint,
  });

  @override
  Future<void> load() async {
    await super.load();
    discord = Discord(
      token: decryptSecret('discord-token', token),
      endpoint: endpoint == null ? null : Uri.parse(endpoint),
    );
    await discord.start();

    discord.connectionStates.listen((state) {
      status = {
        'connected': state.isConnected,
        'guilds': discord.guilds.length,
        if (discord.user != null)
          'user': {
            'id': discord.user.id,
            'name': discord.user.name,
            'discriminator': discord.user.discriminator,
            'avatar': discord.user.avatar().toString(),
          },
      };
    });

    await for (final state in discord.connectionStates) {
      if (state.isConnected) break;
    }
  }
}
