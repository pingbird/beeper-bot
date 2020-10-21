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
    _initializing = true;
    for (final config in botConfig['modules']) {
      final metadata = moduleMetadata.entries.singleWhere((e) => e.value.label == config['type']);
      if (metadata == null) {
        throw StateError('Could not find module of type "${config['type']}"');
      }
      scope.injectWith(metadata.key, metadata.value.factory(), config['id']);
    }
    _initializing = false;

    final dynamic tokenConfig = loadYaml(await File('config/token.yaml').readAsString());
    discord = Discord(token: tokenConfig['token'] as String);

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
  dynamic config;

  @mustCallSuper
  Future<void> load() async {}

  @mustCallSuper
  Future<void> unload() async {}

  @mustCallSuper
  void ready() {}

  @mustCallSuper
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

  Module getWith(Type T, [Object id]) {
    if (T == Module) {
      throw ArgumentError('get requires type argument');
    }
    final key = Tuple2(T, id);
    if (_modules.containsKey(key)) {
      final module = _modules[key];
      if (!module._loaded) {
        throw StateError('Cannot access module that has not finished initialization`');
      }
      return module;
    } else {
      return parent?.getWith(T, id);
    }
  }

  T get<T extends Module>([Object id]) => getWith(T, id) as T;

  FutureOr<Module> requireWith(Type T, [Object id]) async {
    if (T == Module) {
      throw ArgumentError('require requires type argument');
    } else if (!bot._initializing) {
      throw StateError('Cannot use require outside of load');
    }
    var module = getWith(T, id);
    if (module != null) {
      return module;
    }
    final metadata = moduleMetadata[T];
    if (metadata == null) {
      throw StateError('Could not find metadata for module type $T');
    }
    module = metadata.factory();
    _modules[Tuple2(T, id)] = module;
    final startScope = bot.scope;
    bot.scope = this;
    await module.load();
    assert(startScope == this);
    bot.scope = startScope;
    module._loaded = true;
    return module;
  }

  FutureOr<T> require<T extends Module>([Object id]) {
    final result = requireWith(T, id);
    if (result is T) {
      return result;
    } else {
      return (result as Future<Module>).then((v) => v as T);
    }
  }

  void injectWith(Type T, Module module, [Object id]) async {
    if (T == Module) {
      throw ArgumentError('inject requires type argument');
    }
    final key = Tuple2(T, id);
    if (_modules.containsKey(key)) {
      throw StateError('Cannot inject $module: module already exists');
    }
    _modules[Tuple2(T, id)] = module;
  }

  void inject<T extends Module>(Module module, [Object id]) => injectWith(T, module, id);
}