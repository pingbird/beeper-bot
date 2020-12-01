import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

import 'package:beeper/discord/connection.dart';
import 'package:beeper/discord/guild.dart';
import 'package:beeper/discord/state.dart';
import 'package:beeper/discord/http.dart';
export 'package:beeper/discord/guild.dart';

abstract class Snowflake {
  Snowflake._();

  static const int epoch = 1420070400000;

  static DateTime toDateTime(int snowflake) =>
    DateTime.fromMillisecondsSinceEpoch((snowflake >> 22) + epoch, isUtc: true);
}

class Discord extends DiscordState {
  Discord({@required String token}) : super(
    connection: DiscordConnection(
      token: token,
      http: HttpService(
        baseUri: Uri.parse('https://discord.com/api/v7'),
        userAgent: 'Beeper (https://github.com/PixelToast/beeper-bot, eternal beta)',
        authorization: 'Bot ${token.trim()}',
      ),
    ),
  );

  DiscordUser get user => internalUser;

  Map<int, DiscordUser> get users => UnmodifiableMapView(internalUsers);
  Map<int, DiscordGuild> get guilds => UnmodifiableMapView(internalGuilds);
  Map<int, DiscordChannel> get channels => UnmodifiableMapView(internalChannels);
  Map<int, Map<int, DiscordMember>> get members => UnmodifiableMapView(internalMembers);

  Future<void> start() async {
    connection.start();
  }
}