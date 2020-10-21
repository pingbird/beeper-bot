import 'dart:async';
import 'dart:io';

import 'package:beeper/discord/bot.dart';

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

  final _factories = <Type, Object Function()>{};
  var _initializing = false;

  ModuleScope scope;

  void pushScope(Object id) {

  }

  FutureOr<T> require<T extends Module>([Object id]) => scope.require<T>(id);
  FutureOr<T> get<T extends Module>([Object id]) => scope.get<T>(id);
  void inject<T extends Module>(T module, [Object id]) => scope.inject<T>(module, id);

  void register<T extends Module>(T factory()) {
    ArgumentError('register requires type argument');
    assert(!_factories.containsKey(T));
    _factories[T] = factory;
  }
}

abstract class Module {
  var _loaded = false;

  Future<void> load();
  Future<void> unload();
  void ready();
  void dispose();
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
    if (!bot._initializing) {
      throw StateError('Cannot use require outside of load');
    }
    var module = get(id) as T;
    if (module != null) {
      return module;
    }
    final factory = bot._factories[T] as T Function();
    if (factory == null) {
      throw StateError('Could not find factory for type $T');
    }
    module = factory();
    _modules[Tuple2(T, id)] = module;
    await module.load();
    module._loaded = true;
    return module;
  }

  void inject<T extends Module>(T module, [Object id]) async {
    final key = Tuple2(T, id);
    if (_modules.containsKey(key)) {
      throw StateError('Cannot inject $module: module already exists');
    }
    _modules[Tuple2(T, id)] = module;
  }
}