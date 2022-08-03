import 'dart:convert';

import 'package:beeper/modules.dart';
import 'package:beeper/modules/database.dart';
import 'package:beeper/modules/discord.dart';
import 'package:beeper/modules/status.dart';

@Metadata(name: 'discord_history')
class DiscordHistoryModule extends Module
    with StatusLoader, DiscordLoader, DatabaseLoader {
  @override
  Future<void> load() async {
    await super.load();

    discord.onRawMessageCreate.listen((message) async {
      if (message['author'] == null || message['type'] != 0) return;
      await database.con.execute('''
        insert into DiscordMessages
         (Id, RawJson, Channel, UserId, Content, NumEdits, Deleted)
         values (@Id, @RawJson, @Channel, @UserId, @Content, 0, false)
      ''', substitutionValues: <String, dynamic>{
        'Id': int.parse(message['id'] as String),
        'RawJson': jsonEncode(message),
        'Channel': int.parse(message['channel_id'] as String),
        'UserId': int.parse(message['author']['id'] as String),
        'Content': message['content'] as String?,
      });
    });
  }

  @override
  Iterable<dynamic> get dbSetup => const <String>[
        '''
      create table DiscordMessages (
        Id bigint primary key,
        RawJson text,
        Channel bigint,
        UserId bigint,
        Content text,
        NumEdits integer,
        Deleted boolean
      );
      
      create table DiscordMessageEdits (
        MessageId bigint,
        EditNumber integer,
        EditAt timestamp,
        RawJson text,
        LastContent text,
        unique(MessageId, EditNumber)
      );
    ''',
      ];
}
