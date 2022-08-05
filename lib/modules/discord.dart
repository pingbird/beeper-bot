import 'package:beeper/discord/discord.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules/disposer.dart';
import 'package:beeper/modules/status.dart';
import 'package:beeper/secrets.dart';
import 'package:beeper_common/admin.dart';
import 'package:beeper_common/debouncer.dart';

mixin DiscordLoader on Module {
  late final Discord discord;

  @override
  Future<void> load() async {
    await super.load();
    discord = (await scope.require<DiscordModule>()).discord;
  }
}

@Metadata(name: 'discord')
class DiscordModule extends Module with StatusLoader, Disposer {
  final String token;
  final String? endpoint;

  DiscordModule({
    required this.token,
    this.endpoint,
  });

  late final Discord discord;

  late final _statusUpdateDebouncer = Debouncer(
    minDuration: const Duration(milliseconds: 200),
    maxDuration: const Duration(milliseconds: 500),
    onUpdate: (_) => updateStatus(),
  );

  void updateStatus() {
    status = <String, dynamic>{
      'connected': discord.connectionState.isConnected,
      'guilds': [
        for (final guild in discord.guilds.entries)
          if (guild.value.available)
            DiscordGuildDto(
              id: '${guild.key}',
              name: guild.value.name!,
              icon: '${guild.value.icon(size: 64)}',
            ),
      ],
      if (discord.user != null)
        'user': {
          'snowflake': discord.user!.id.toString(),
          'name': discord.user!.name,
          'discriminator': discord.user!.discriminator,
          'avatar': discord.user!.avatar().toString(),
        },
    };
  }

  @override
  Future<void> load() async {
    await super.load();
    discord = Discord(
      token: decryptSecret('discord-token', token),
      endpoint: endpoint == null ? null : Uri.parse(endpoint!),
    );
    await discord.start();

    queueDispose(discord.connectionStates.listen(
      (state) => _statusUpdateDebouncer.add(null),
    ));

    queueDispose(discord.onGuildCreate.listen(
      (event) => _statusUpdateDebouncer.add(null),
    ));

    queueDispose(discord.onGuildDestroy.listen(
      (event) => _statusUpdateDebouncer.add(null),
    ));

    await for (final state in discord.connectionStates) {
      if (state.isConnected) break;
    }
  }
}
