import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:beeper/discord/connection.dart';
import 'package:beeper/discord/guild.dart';
import 'package:beeper/discord/http.dart';
import 'package:beeper/discord/state.dart';
import 'package:meta/meta.dart';

export 'package:beeper/discord/guild.dart';

abstract class Snowflake {
  Snowflake._();

  static const int epoch = 1420070400000;

  static DateTime toDateTime(int snowflake) =>
      DateTime.fromMillisecondsSinceEpoch(
        (snowflake >> 22) + epoch,
        isUtc: true,
      );

  static int random() {
    final rand = Random();
    return rand.nextInt(1 << 22) + (rand.nextInt(157680000) * 1000 << 22);
  }
}

class Discord extends DiscordState {
  Discord({
    @required String token,
    Uri endpoint,
    String userAgent =
        'Beeper (https://github.com/PixelToast/beeper-bot, eternal beta)',
  }) : super(
          connection: DiscordConnection(
            token: token,
            http: HttpService(
              endpoint: endpoint ?? Uri.parse('https://discord.com/api/v7'),
              userAgent: userAgent,
              authorization: 'Bot ${token.trim()}',
            ),
          ),
        );

  DiscordUser get user => internalUser;

  Map<int, DiscordUser> get users => UnmodifiableMapView(internalUsers);
  Map<int, DiscordGuild> get guilds => UnmodifiableMapView(internalGuilds);
  Map<int, DiscordChannel> get channels =>
      UnmodifiableMapView(internalChannels);
  Map<int, Map<int, DiscordMember>> get members =>
      UnmodifiableMapView(internalMembers);

  Future<void> start() async {
    // TODO(ping): Should we wait for ready event?
    connection.start();
  }

  void destroy() {
    // TODO(ping): destroy things here
  }
}
