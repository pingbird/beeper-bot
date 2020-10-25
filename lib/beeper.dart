import 'dart:async';
import 'dart:io';

import 'package:beeper/discord/discord.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules.g.dart';

import 'package:yaml/yaml.dart';
import 'package:hotreloader/hotreloader.dart';

final _botKey = Object();
Bot get bot => Zone.current[_botKey] as Bot;

class Bot extends ModuleSystem {
  Discord discord;

  T wrap<T>(T Function() fn) => runZonedGuarded(
    fn,
    (e, bt) {
      stderr.writeln('$e\n$bt');
    },
    zoneValues: {
      _botKey: this,
    },
  );

  void start() => wrap(() async {
    final dynamic botConfig = loadYaml(await File('config/bot.yaml').readAsString());

    if (botConfig['development'] == true) {
      stderr.writeln('Hot reload started');
      await HotReloader.create(
        onAfterReload: (ctx) {
          stderr.writeln('Hot reload finished with ${ctx.result}');
        }
      );
    }

    scope = ModuleScope(bot: this, parent: null);
    initializing = true;
    for (final config in botConfig['modules']) {
      final metadata = moduleMetadata.entries.singleWhere((e) => e.value.label == config['type']);
      if (metadata == null) {
        throw StateError('Could not find module of type "${config['type']}"');
      }
      scope.injectWith(metadata.key, metadata.value.factory(), config['id']);
    }
    initializing = false;

    final dynamic tokenConfig = loadYaml(await File('config/token.yaml').readAsString());
    discord = Discord(token: tokenConfig['token'] as String);

    await discord.start();

    await for (var state in discord.connectionStates) {
      if (state.isConnected) break;
    }

    print('woo! ${discord.user.name}');
  });

  ModuleScope scope;

  void pushScope(Object id) {
    if (scope.children.containsKey(id)) {
      throw StateError('Cannot push scope: $id already exists');
    }
    final newScope = ModuleScope(bot: this, parent: scope);
    scope.children[id] = newScope;
    scope = newScope;
  }

  void popScope() {
    scope = scope.parent;
    assert(scope != null);
  }

  FutureOr<T> require<T extends Module>([Object id]) => scope.require<T>(id);
  FutureOr<T> get<T extends Module>([Object id]) => scope.get<T>(id);
  void inject<T extends Module>(T module, [Object id]) => scope.inject<T>(module, id);
}