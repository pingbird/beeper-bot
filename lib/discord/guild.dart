import 'package:beeper/discord/discord.dart';
import 'package:meta/meta.dart';

class DiscordGuild {
  final Discord discord;
  final int id;

  String name;
  bool available = false;

  DiscordGuild({
    @required this.discord,
    @required this.id,
  });

  void updateEntity(dynamic data) {
    name = data['name'] as String ?? name;
    available = data['unavailable'] != true;
  }
}

class UserFlags {
  final int value;

  UserFlags(this.value);

  bool get discordEmployee      => value & (1 << 0) != 0;
  bool get partneredServerOwner => value & (1 << 1) != 0;
  bool get hypeSquadEvents      => value & (1 << 2) != 0;
  bool get bugHunterLvl1        => value & (1 << 3) != 0;
  bool get houseBravery         => value & (1 << 6) != 0;
  bool get houseBrilliance      => value & (1 << 7) != 0;
  bool get houseBalance         => value & (1 << 8) != 0;
  bool get earlySupporter       => value & (1 << 9) != 0;
  bool get teamUser             => value & (1 << 10) != 0;
  bool get system               => value & (1 << 12) != 0;
  bool get bugHunterLvl2        => value & (1 << 14) != 0;
  bool get verifiedBot          => value & (1 << 16) != 0;
  bool get earlyVerifiedBotDev  => value & (1 << 17) != 0;
}

class DiscordUser {
  final Discord discord;
  final int id;

  DiscordUser({
    @required this.discord,
    @required this.id,
  });

  String name;
  int discriminator;
  bool bot;
  bool system;
  bool mfaEnabled;
  String locale;
  UserFlags flags;

  void updateEntity(dynamic data) {
    name = data['username'] as String;
    discriminator = int.tryParse(data['discriminator'] as String);
    bot = data['bot'] as bool ?? false;
    system = data['system'] as bool ?? false;
    mfaEnabled = data['mfa_enabled'] as bool ?? false;
    locale = data['locale'] as String;
    if (data['public_flags'] != null) {
      flags = UserFlags(data['public_flags'] as int);
    }
  }
}

class DiscordMember {
  final DiscordUser user;

  DiscordMember({
    @required this.user,
  });

  String nick;
  DateTime joinedAt;

  String get name => nick ?? user.name;
  int get id => user.id;

  void updateEntity(dynamic data) {
    nick = data['nick'] as String;
    joinedAt = DateTime.parse(data['joinedAt'] as String);
  }
}