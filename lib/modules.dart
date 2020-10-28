import 'dart:async';

import 'package:beeper/beeper.dart';
import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

import 'package:beeper/modules.g.dart';

abstract class ModuleSystem {
  var initializing = false;
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
  @protected
  Future<void> load() async {}

  @mustCallSuper
  @protected
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

  void _visitModules(void Function(Module module) fn) {
    assert(!bot.initializing);
    _modules.values.forEach(fn);
    for (final child in children.values) {
      child._visitModules(fn);
    }
  }

  void visitModules(void Function(Module module) fn) {
    final visited = <Module>{};
    _visitModules((module) {
      if (visited.add(module)) {
        fn(module);
      }
    });
  }

  Module getWith(Type T, {Object id}) {
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
      return parent?.getWith(T, id: id);
    }
  }

  T get<T extends Module>({Object id}) => getWith(T, id: id) as T;

  Future<Module> requireWith(Type T, [Object id]) async {
    if (T == Module) {
      throw ArgumentError('require requires type argument');
    } else if (!bot.initializing) {
      throw StateError('Cannot use require outside of load');
    }
    var module = getWith(T, id: id);
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

  Future<T> require<T extends Module>({Object id}) async {
    final result = await requireWith(T, id);
    if (result is T) {
      return result;
    } else {
      return (result as Future<Module>).then((v) => v as T);
    }
  }

  Future<void> injectWith(Type T, Module module, {Object id}) async {
    if (T == Module) {
      throw ArgumentError('inject requires type argument');
    }
    if (!module._loaded) {
      await module.load();
      module._loaded = true;
    }
    final key = Tuple2(T, id);
    if (_modules.containsKey(key)) {
      throw StateError('Cannot inject $module: module already exists');
    }
    _modules[Tuple2(T, id)] = module;
  }

  Future<void> inject<T extends Module>(Module module, [Object id]) => injectWith(T, module, id: id);
}