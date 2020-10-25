import 'dart:collection';

import 'package:beeper/discord/discord.dart';
import 'package:beeper/discord/http.dart';
import 'package:meta/meta.dart';

import 'package:beeper/discord/connection.dart';
import 'package:beeper/discord/guild.dart';
import 'package:rxdart/rxdart.dart';

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

  DiscordState({
    @required DiscordConnection connection,
  }) : _connection = connection {
    _connection.onReady = ({
      Object user,
      List<Object> guilds,
    }) {
      _userSubject.value = _updateUserEntity(user);
      guilds.forEach(_updateGuildEntity);
    };
  }

  DiscordConnectionState get connectionState => _connection.state;
  ValueObservable<DiscordConnectionState> get connectionStates => _connection.states;

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