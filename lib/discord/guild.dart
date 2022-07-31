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
  final int /*!*/ value;

  UserFlags(this.value);

  bool get discordEmployee => value & (1 << 0) != 0;
  bool get partneredServerOwner => value & (1 << 1) != 0;
  bool get hypeSquadEvents => value & (1 << 2) != 0;
  bool get bugHunterLvl1 => value & (1 << 3) != 0;
  bool get houseBravery => value & (1 << 6) != 0;
  bool get houseBrilliance => value & (1 << 7) != 0;
  bool get houseBalance => value & (1 << 8) != 0;
  bool get earlySupporter => value & (1 << 9) != 0;
  bool get teamUser => value & (1 << 10) != 0;
  bool get system => value & (1 << 12) != 0;
  bool get bugHunterLvl2 => value & (1 << 14) != 0;
  bool get verifiedBot => value & (1 << 16) != 0;
  bool get earlyVerifiedBotDev => value & (1 << 17) != 0;
}

class DiscordUser {
  final Discord discord;
  final int id;

  DiscordUser({
    @required this.discord,
    @required this.id,
  });

  String /*!*/ name;
  int /*!*/ discriminator;
  String /*?*/ avatarHash;
  bool /*!*/ bot;
  bool /*!*/ system;
  bool /*!*/ mfaEnabled;
  String /*?*/ locale;
  UserFlags /*!*/ flags;

  void updateEntity(dynamic data) {
    name = data['username'] as String;
    discriminator = int.parse(data['discriminator'] as String);
    avatarHash = data['avatar'] as String /*?*/;
    bot = data['bot'] as bool ?? false;
    system = data['system'] as bool ?? false;
    mfaEnabled = data['mfa_enabled'] as bool ?? false;
    locale = data['locale'] as String /*?*/;
    if (data['public_flags'] != null) {
      flags = UserFlags(data['public_flags'] as int);
    } else {
      flags = UserFlags(0);
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

  String mention({bool ping = true}) => '<@${ping ? '!' : ''}$id>';

  Pattern get mentionPattern => RegExp('<@!?$id>');
}

class DiscordMember {
  final DiscordGuild guild;
  final DiscordUser /*?*/ user;

  DiscordMember({
    @required this.guild,
    @required this.user,
  });

  String /*?*/ nick;
  DateTime joinedAt;

  String get name => nick ?? user.name;
  int get id => user.id;

  void updateEntity(dynamic data) {
    nick = data['nick'] as String /*?*/;
    joinedAt = DateTime.parse(data['joinedAt'] as String);
  }
}

enum DiscordChannelKind {
  Text,
  Direct,
  Voice,
  Group,
  Category,
  News,
  Store,
  Reserved7,
  Reserved8,
  Reserved9,
  NewsThread,
  PublicThread,
  PrivateThread,
  StageVoice,
  Directory,
  Forum,
}

class DiscordChannel {
  final Discord discord;
  final int id;
  final DiscordChannelKind kind;
  final DiscordGuild /*?*/ guild;

  int /*!*/ position;
  String /*?*/ name;
  String /*?*/ topic;
  bool /*!*/ nsfw;

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

  Future<DiscordMessage> send(String content) async {
    final dynamic data = await discord.http.post(
      'channels/$id/messages',
      body: <String, dynamic>{
        'content': content,
      },
    );

    return discord.wrapMessage(data);
  }
}

class DiscordEmbedProvider {
  final String name;
  final String url;

  DiscordEmbedProvider({
    this.name,
    this.url,
  });

  DiscordEmbedProvider.fromJson(dynamic data)
      : name = data['name'] as String,
        url = data['url'] as String;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'url': url,
      };
}

class DiscordEmbedSource {
  final String url;
  final String cdnUrl;
  final int width;
  final int height;

  DiscordEmbedSource({
    @required this.url,
    this.cdnUrl,
    this.width,
    this.height,
  });

  DiscordEmbedSource.fromJson(dynamic data)
      : url = data['url'] as String,
        cdnUrl = data['cdnUrl'] as String,
        width = data['width'] as int,
        height = data['height'] as int;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'url': url,
        if (cdnUrl != null) 'cdnUrl': cdnUrl,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
      };
}

class DiscordEmbedFooter {
  final String text;
  final String iconUrl;
  final String iconCdnUrl;

  DiscordEmbedFooter({
    @required this.text,
    this.iconUrl,
    this.iconCdnUrl,
  });

  DiscordEmbedFooter.fromJson(dynamic data)
      : text = data['text'] as String,
        iconUrl = data['iconUrl'] as String,
        iconCdnUrl = data['iconCdnUrl'] as String;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'text': text,
        if (iconUrl != null) 'iconUrl': iconUrl,
        if (iconCdnUrl != null) 'iconCdnUrl': iconCdnUrl,
      };
}

class DiscordEmbedAuthor {
  final String name;
  final String url;
  final String iconUrl;
  final String iconCdnUrl;

  DiscordEmbedAuthor({
    this.name,
    this.url,
    this.iconUrl,
    this.iconCdnUrl,
  });

  DiscordEmbedAuthor.fromJson(dynamic data)
      : name = data['name'] as String,
        url = data['url'] as String,
        iconUrl = data['iconUrl'] as String,
        iconCdnUrl = data['iconCdnUrl'] as String;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (name != null) 'name': name,
        if (url != null) 'url': url,
        if (iconUrl != null) 'iconUrl': iconUrl,
        if (iconCdnUrl != null) 'iconCdnUrl': iconCdnUrl,
      };
}

class DiscordEmbedField {
  final String name;
  final String value;
  final bool inline;

  DiscordEmbedField({
    this.name,
    this.value,
    this.inline,
  });

  DiscordEmbedField.fromJson(dynamic data)
      : name = data['name'] as String,
        value = data['value'] as String,
        inline = data['inline'] as bool ?? false;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'value': value,
        if (inline) 'inline': true,
      };
}

class DiscordEmbed {
  final String title;
  final String type;
  final String description;
  final String url;
  final DateTime timestamp;
  final int color;
  final DiscordEmbedFooter footer;
  final DiscordEmbedSource thumbnail;
  final DiscordEmbedProvider provider;
  final DiscordEmbedSource image;
  final DiscordEmbedSource video;
  final DiscordEmbedAuthor author;
  final List<DiscordEmbedField> fields;

  DiscordEmbed({
    this.title,
    this.type,
    this.description,
    this.url,
    this.timestamp,
    this.color,
    this.footer,
    this.thumbnail,
    this.provider,
    this.image,
    this.video,
    this.author,
    this.fields,
  });

  DiscordEmbed.fromJson(dynamic data)
      : title = data['title'] as String,
        type = data['type'] as String,
        description = data['description'] as String,
        url = data['url'] as String,
        timestamp = DateTime.parse(data['timestamp'] as String),
        color = data['color'] as int,
        footer = data['footer'] == null
            ? null
            : DiscordEmbedFooter.fromJson(data['footer']),
        thumbnail = data['thumbnail'] == null
            ? null
            : DiscordEmbedSource.fromJson(data['thumbnail']),
        provider = data['provider'] == null
            ? null
            : DiscordEmbedProvider.fromJson(data['provider']),
        image = data['image'] == null
            ? null
            : DiscordEmbedSource.fromJson(data['provider']),
        video = data['video'] == null
            ? null
            : DiscordEmbedSource.fromJson(data['video']),
        author = data['author'] == null
            ? null
            : DiscordEmbedAuthor.fromJson(data['provider']),
        fields = data['fields'] == null
            ? null
            : [
                for (final field in data['fields'])
                  DiscordEmbedField.fromJson(field)
              ];

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (title != null) 'title': title,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
        if (url != null) 'url': url,
        if (timestamp != null) 'timestamp': timestamp.toIso8601String(),
        if (color != null) 'color': color,
        if (footer != null) 'footer': footer,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (provider != null) 'provider': provider,
        if (image != null) 'image': image,
        if (video != null) 'video': video,
        if (author != null) 'author': author,
        if (fields != null) 'fields': fields,
      };
}

class DiscordAttachment {
  final int id;
  final String filename;
  final int size;
  final String url;
  final String proxyUrl;
  final int /*?*/ width;
  final int /*?*/ height;

  DiscordAttachment({
    @required this.id,
    @required this.filename,
    @required this.size,
    @required this.url,
    @required this.proxyUrl,
    this.width,
    this.height,
  });

  DiscordAttachment.fromJson(dynamic data)
      : id = int.parse(data['id'] as String),
        filename = data['name'] as String,
        size = data['size'] as int,
        url = data['url'] as String,
        proxyUrl = data['proxy_url'] as String,
        width = data['width'] as int,
        height = data['height'] as int;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': filename,
        'size': size,
        'url': url,
        'proxy_url': proxyUrl,
        'width': width,
        'height': height,
      };
}

class DiscordMessage {
  final int id;
  final dynamic rawJson;
  final DiscordChannel channel;
  final DiscordUser user;
  final String /*!*/ content;
  final List<DiscordAttachment> attachments;
  final List<DiscordEmbed> embeds;

  DiscordMessage({
    @required this.id,
    @required this.rawJson,
    @required this.channel,
    @required this.user,
    @required this.content,
    @required this.attachments,
    @required this.embeds,
  });

  // TODO: !
  DiscordGuild get guild => channel.guild;
  DiscordMember get member => guild.members[user.id];

  Future<DiscordMessage> reply(String content) => channel.send(content);
}
