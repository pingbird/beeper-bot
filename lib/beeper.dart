import 'dart:async';
import 'dart:io';

import 'package:beeper/discord/bot.dart';
import 'package:beeper/modules.g.dart';

import 'package:tuple/tuple.dart';
import 'package:yaml/yaml.dart';
import 'package:hotreloader/hotreloader.dart';
import 'package:meta/meta.dart';

final _botKey = Object();
Bot get bot => Zone.current[_botKey] as Bot;

class Bot {
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
    final dynamic config = loadYaml(await File('config.yaml').readAsString());
    discord = Discord(token: config['token'] as String);

    scope = ModuleScope(bot: this, parent: null);

    if (config['development'] == true) {
      stderr.writeln('Hot reload started');
      await HotReloader.create(
        onAfterReload: (ctx) {
          stderr.writeln('Hot reload finished with ${ctx.result}');
        }
      );
    }
    await discord.initialize();
  });

  var _initializing = false;

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

class ModuleMetadata {
  final String label;
  final Module Function() factory;

  ModuleMetadata({
    @required this.label,
    @required this.factory,
  });
}

abstract class Module {
  var _loaded = false;
  dynamic configuration;

  Future<void> load() async {}
  Future<void> unload() async {}
  void ready() {}
  void dispose() {}
}

class ModuleScope {
  final Bot bot;
  final ModuleScope parent;

  ModuleScope({
    @required this.bot,
    @required this.parent,
  });

  final children = <Object, ModuleScope>{};
  final _modules = <Tuple2<Type, Object>, Module>{};

  T get<T extends Module>([Object id]) {
    if (T == Module) {
      throw ArgumentError('get requires type argument');
    }
    final key = Tuple2(T, id);
    if (_modules.containsKey(key)) {
      final module = _modules[key] as T;
      if (!module._loaded) {
        throw StateError('Cannot access module that has not finished initialization`');
      }
      return module;
    } else {
      return parent?.get(id);
    }
  }

  FutureOr<T> require<T extends Module>([Object id]) async {
    if (T == Module) {
      throw ArgumentError('require requires type argument');
    } else if (!bot._initializing) {
      throw StateError('Cannot use require outside of load');
    }
    var module = get(id) as T;
    if (module != null) {
      return module;
    }
    final metadata = moduleMetadata[T];
    if (metadata == null) {
      throw StateError('Could not find metadata for module type $T');
    }
    module = (metadata.factory as T Function())();
    _modules[Tuple2(T, id)] = module;
    final startScope = bot.scope;
    bot.scope = this;
    await module.load();
    assert(startScope == this);
    bot.scope = startScope;
    module._loaded = true;
    return module;
  }

  void inject<T extends Module>(T module, [Object id]) async {
    if (T == Module) {
      throw ArgumentError('inject requires type argument');
    }
    final key = Tuple2(T, id);
    if (_modules.containsKey(key)) {
      throw StateError('Cannot inject $module: module already exists');
    }
    _modules[Tuple2(T, id)] = module;
  }
}