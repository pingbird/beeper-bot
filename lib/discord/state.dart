import 'dart:async';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'package:beeper/discord/connection.dart';
import 'package:beeper/discord/guild.dart';
import 'package:beeper/discord/discord.dart';
import 'package:beeper/discord/http.dart';

extension DiscordStateInternal on DiscordState {
  HttpService get http => _connection.http;
  DiscordConnection get connection => _connection;
  void updateGuildEntity(dynamic data) => _updateGuildEntity(data);
  void updateUserEntity(dynamic data) => _updateUserEntity(data);
  Map<int, DiscordUser> get internalUsers => _users;
  Map<int, DiscordGuild> get internalGuilds => _guilds;
}

abstract class DiscordState {
  final DiscordConnection _connection;

  Stream<DiscordGuild> get onGuildCreate => _onGuildCreate.stream;
  final _onGuildCreate = StreamController<DiscordGuild>.broadcast();

  Stream<DiscordGuild> get onGuildDestroy => _onGuildCreate.stream;
  final _onGuildDestroy = StreamController<DiscordGuild>.broadcast();

  Stream<DiscordMessage> get onMessageCreate => _onMessageCreate.stream;
  final _onMessageCreate = StreamController<DiscordMessage>.broadcast();

  Stream<DiscordGuildMessage> get onGuildMessageCreate => _onGuildMessageCreate.stream;
  final _onGuildMessageCreate = StreamController<DiscordGuildMessage>.broadcast();

  DiscordState({
    @required DiscordConnection connection,
  }) : _connection = connection {
    _connection.onEvent = _onEvent;
    _onMessageCreate.addStream(onGuildMessageCreate);
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
        break;
      case 'MESSAGE_CREATE':
        if (data['guild_id'] != null) {
          _onGuildMessageCreate.add(DiscordGuildMessage(
            id: int.parse(data['id'] as String),
            guild: _guilds[int.parse(data['guild_id'] as String)],
            content: data['content'] as String,
          ));
        }
        break;
      default:
        break;
    }
  }

  DiscordConnectionState get connectionState => _connection.state;
  ValueStream<DiscordConnectionState> get connectionStates => _connection.states;

  final _userSubject = BehaviorSubject<DiscordUser>();
  DiscordUser get user => _userSubject.value;

  final _users = <int, DiscordUser>{};
  final _guilds = <int, DiscordGuild>{};

  DiscordGuild _updateGuildEntity(dynamic data) {
    final id = int.parse(data['id'] as String);
    final guild = _guilds.putIfAbsent(id, () => DiscordGuild(
      discord: this as Discord,
      id: id,
    ));
    guild.updateEntity(data);
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
}