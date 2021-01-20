import 'dart:async';

import 'package:beeper_common/logging.dart';
import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'package:beeper/discord/connection.dart';
import 'package:beeper/discord/guild.dart';
import 'package:beeper/discord/discord.dart';
import 'package:beeper/discord/http.dart';

extension DiscordStateInternal on DiscordState {
  HttpService get http => _connection.http;
  DiscordConnection get connection => _connection;
  DiscordGuild updateGuildEntity(dynamic data) => _updateGuildEntity(data);
  DiscordUser updateUserEntity(dynamic data) => _updateUserEntity(data);
  DiscordChannel updateChannelEntity(dynamic data) => _updateChannelEntity(data);
  DiscordMember updateMemberEntity(dynamic data, {
    @required DiscordGuild guild,
    DiscordUser user,
  }) => _updateMemberEntity(data, guild: guild, user: user);
  DiscordMessage wrapMessage(dynamic data) => _wrapMessage(data);

  DiscordUser get internalUser => _userSubject.value;

  Map<int, DiscordUser> get internalUsers => _users;
  Map<int, DiscordGuild> get internalGuilds => _guilds;
  Map<int, DiscordChannel> get internalChannels => _channels;
  Map<int, Map<int, DiscordMember>> get internalMembers => _members;
}

abstract class DiscordState {
  final DiscordConnection _connection;

  Stream<DiscordGuild> get onGuildCreate => _onGuildCreate.stream;
  final _onGuildCreate = StreamController<DiscordGuild>.broadcast();

  Stream<DiscordGuild> get onGuildDestroy => _onGuildCreate.stream;
  final _onGuildDestroy = StreamController<DiscordGuild>.broadcast();

  Stream<DiscordMessage> get onMessageCreate => _onMessageCreate.stream;
  final _onMessageCreate = StreamController<DiscordMessage>.broadcast();

  DiscordState({
    @required DiscordConnection connection,
  }) : _connection = connection {
    _connection.onEvent = _onEvent;
  }

  void _onEvent(String name, dynamic data) {
    switch (name) {
      case 'READY':
        _userSubject.value = _updateUserEntity(data['user']);
        (data['guilds'] as List<Object>).forEach(_updateGuildEntity);
        break;
      case 'GUILD_CREATE':
        _updateGuildEntity(data);
        break;
      case 'GUILD_UPDATE':
        _updateGuildEntity(data);
        break;
      case 'GUILD_DELETE':
        final guild = _updateGuildEntity(data);
        guild.destroyed = true;
        _onGuildDestroy.add(guild);
        _members.remove(guild.id);
        break;
      case 'CHANNEL_CREATE':
        _updateChannelEntity(data);
        break;
      case 'CHANNEL_UPDATE':
        _updateChannelEntity(data);
        break;
      case 'MESSAGE_CREATE':
        // Ignore webhook messages (for now)
        if (data['webhook_id'] != null) {
          break;
        }
        _onMessageCreate.add(_wrapMessage(data));
        break;
      default:
        break;
    }
  }

  DiscordConnectionState get connectionState => _connection.state;
  ValueStream<DiscordConnectionState> get connectionStates => _connection.states;

  final _userSubject = BehaviorSubject<DiscordUser>();

  final _users = <int, DiscordUser>{};
  final _guilds = <int, DiscordGuild>{};
  final _channels = <int, DiscordChannel>{};
  final _members = <int, Map<int, DiscordMember>>{};

  DiscordGuild _updateGuildEntity(dynamic data) {
    final id = int.parse(data['id'] as String);
    _members[id] ??= {};
    final guild = _guilds.putIfAbsent(id, () => DiscordGuild(
      discord: this as Discord,
      id: id,
    ));
    guild.updateEntity(data);

    if (data['channels'] != null) {
      (data['channels'] as List<dynamic>).forEach(_updateChannelEntity);
    }

    return guild;
  }

  DiscordUser _updateUserEntity(dynamic data) {
    final id = int.parse(data['id'] as String);
    final user = _users.putIfAbsent(id, () => DiscordUser(
      discord: this as Discord,
      id: id,
    ));
    user.updateEntity(data);
    return user;
  }

  DiscordChannel _updateChannelEntity(dynamic data) {
    final id = int.parse(data['id'] as String);
    DiscordGuild guild;
    if (data['guild_id'] != null) {
      guild = _guilds[int.parse(data['guild_id'] as String)];
      if (guild == null) {
        logger.log('discord', 'Guild for channel $id could not be found', level: LogLevel.warning);
      }
    }
    final user = _channels.putIfAbsent(id, () => DiscordChannel(
      discord: this as Discord,
      id: id,
      kind: DiscordChannelKind.values[data['type'] as int],
      guild: guild,
    ));
    user.updateEntity(data);
    return user;
  }

  DiscordMember _updateMemberEntity(dynamic data, {
    @required DiscordGuild guild,
    DiscordUser user,
  }) {
    user ??= _updateUserEntity(data['user']);
    final member = _members[guild.id].putIfAbsent(user.id, () => DiscordMember(
      guild: guild,
      user: user,
    ));
    member.updateEntity(data);
    return member;
  }

  DiscordMessage _wrapMessage(dynamic data) {
    final id = int.parse(data['id'] as String);
    final channelId = int.parse(data['channel_id'] as String);
    final channel = _channels[channelId];
    if (channel == null) {
      logger.log('discord', 'Channel $channelId for message $id could not be found', level: LogLevel.warning);
    }
    final user = _updateUserEntity(data['author']);
    return DiscordMessage(
      id: id,
      channel: channel,
      user: user,
      content: data['content'] as String,
    );
  }
}