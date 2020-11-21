import 'dart:collection';

import 'package:beeper/discord/discord.dart';
import 'package:beeper/discord/state.dart';
import 'package:meta/meta.dart';

class DiscordGuild {
  final Discord discord;
  final int id;

  DiscordGuild({
    @required this.discord,
    @required this.id,
  });

  String name;
  bool available = false;
  bool destroyed = false;

  Map<int, DiscordMember> get members =>
    UnmodifiableMapView(discord.internalMembers[id]);

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
  String avatarHash;
  bool bot;
  bool system;
  bool mfaEnabled;
  String locale;
  UserFlags flags;

  void updateEntity(dynamic data) {
    name = data['username'] as String;
    discriminator = int.tryParse(data['discriminator'] as String);
    avatarHash = data['avatar'] as String;
    bot = data['bot'] as bool ?? false;
    system = data['system'] as bool ?? false;
    mfaEnabled = data['mfa_enabled'] as bool ?? false;
    locale = data['locale'] as String;
    if (data['public_flags'] != null) {
      flags = UserFlags(data['public_flags'] as int);
    }
  }

  Uri avatar({
    String format,
    int size,
  }) {
    if (avatarHash == null) {
      return Uri(
        scheme: 'https',
        host: 'cdn.discordapp.com',
        path: 'embed/avatars/${discriminator % 5}.png',
      );
    } else {
      format ??= avatarHash.startsWith('a_') ? 'gif' : 'png';
      return Uri(
        scheme: 'https',
        host: 'cdn.discordapp.com',
        path: 'avatars/$id/$avatarHash.$format',
        queryParameters: <String, String>{
          if (size != null) 'size': '$size',
        },
      );
    }
  }
}

class DiscordMember {
  final DiscordGuild guild;
  final DiscordUser user;

  DiscordMember({
    @required this.guild,
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

enum DiscordChannelKind {
  GuildText,
  Direct,
  GuildVoice,
  Group,
  GuildCategory,
  GuildNews,
  GuildStore,
}

class DiscordChannel {
  final Discord discord;
  final int id;
  final DiscordChannelKind kind;
  final DiscordGuild guild;

  int position;
  String name;
  String topic;
  bool nsfw;

  DiscordChannel({
    @required this.discord,
    @required this.id,
    @required this.kind,
    this.guild,
  });

  void updateEntity(dynamic data) {
    position = data['position'] as int;
    name = data['name'] as String;
    topic = data['topic'] as String;
    nsfw = data['nsfw'] as bool;
  }

  Future<DiscordMessage> send({
    String content,
  }) async {
    final dynamic data = await discord.http.post(
      'channels/$id/messages',
      body: <String, dynamic>{
        'content': content,
      },
    );

    return discord.wrapMessage(data);
  }
}

class DiscordMessage {
  final int id;
  final DiscordChannel channel;
  final DiscordUser user;
  final String content;

  DiscordMessage({
    @required this.id,
    @required this.channel,
    @required this.user,
    @required this.content,
  });

  DiscordGuild get guild => channel.guild;
  DiscordMember get member => guild.members[user.id];

  Future<DiscordMessage> reply({
    String content,
  }) => channel.send(
    content: content,
  );
}