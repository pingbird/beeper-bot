import 'dart:async';
import 'dart:collection';

import 'package:beeper/gen/modules.g.dart';
import 'package:meta/meta.dart';
import 'package:tuple/tuple.dart';

export 'package:beeper/gen/modules.g.dart';

class Metadata {
  final String name;
  final bool lazyLoad;
  final Module Function(dynamic data) factory;
  final bool loadable;
  final bool configurable;

  const Metadata({
    @required this.name,
    this.lazyLoad,
    this.factory,
    this.loadable = false,
    this.configurable = true,
  });
}

abstract class ModuleSystem {
  @protected
  var initializing = false;

  ModuleScope scope;
}

abstract class Module {
  ModuleSystem system;
  ModuleScope scope;

  Completer<void> _loaded;
  bool get loaded => _loaded.isCompleted;

  String get canonicalName {
    final key = scope.modules.entries
        .singleWhere(
          (element) => element.value == this,
        )
        .key;
    final metadata = moduleMetadata[key.item1];
    final scopeName = scope.canonicalName;
    if (key.item2 == null) {
      return '$scopeName/${metadata.name}';
    } else {
      return '$scopeName/${key.item2}#${metadata.name}';
    }
  }

  Future<void> _performLoad({
    @required ModuleSystem system,
    @required ModuleScope scope,
  }) async {
    if (_loaded == null) {
      _loaded = Completer();
      this.system = system;
      this.scope = scope;
      await load();
      _loaded.complete();
    } else {
      return _loaded.future;
    }
  }

  @mustCallSuper
  @protected
  Future<void> load() async {
    assert(scope != null);
  }

  @mustCallSuper
  @protected
  Future<void> unload() async {}

  @mustCallSuper
  void dispose() {}
}

class ModuleScope {
  final ModuleSystem system;
  final ModuleScope parent;

  ModuleScope({
    @required this.system,
    @required this.parent,
  });

  final _children = <Object, ModuleScope>{};
  final _modules = <Tuple2<Type, Object>, Module>{};
  ModuleScope _inherit;

  Map<Object, ModuleScope> get children => UnmodifiableMapView(_children);
  Map<Tuple2<Type, Object>, Module> get modules =>
      UnmodifiableMapView(_modules);

  String _canonicalName;

  String get canonicalName {
    if (_canonicalName == null) {
      if (parent == null) {
        _canonicalName = '';
      } else {
        final key = children.entries
            .singleWhere((element) => element.value == this)
            .key;
        _canonicalName = '${parent.canonicalName}/$key';
      }
    }
    return _canonicalName;
  }

  ModuleScope push(Object id) {
    if (_children.containsKey(id)) {
      return _children[id];
    } else if (_inherit._children.containsKey(id)) {
      final scope = ModuleScope(system: system, parent: this);
      scope._inherit = _inherit._children[id];
      _children[id] = scope;
      return scope;
    } else {
      final scope = ModuleScope(system: system, parent: this);
      _children[id] = scope;
      return scope;
    }
  }

  void _visitModules(void Function(Module module) fn) {
    assert(!system.initializing);
    _modules.values.forEach(fn);
    for (final child in _children.values) {
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
      if (!module._loaded.isCompleted) {
        throw StateError(
          'Cannot access module that has not finished initialization`',
        );
      }
      return module;
    } else if (_inherit != null && _inherit._modules.containsKey(key)) {
      final module = _inherit._modules[key];
      assert(module._loaded.isCompleted);
      module.scope = this;
      _modules[key] = module;
      return module;
    } else {
      return parent?.getWith(T, id: id);
    }
  }

  T get<T extends Module>({Object id}) => getWith(T, id: id) as T;

  Future<Module> requireWith(Type T, [Object id]) async {
    if (T == Module) {
      throw ArgumentError('require requires type argument');
    } else if (!system.initializing) {
      throw StateError('Cannot use require outside of load method');
    }
    var module = getWith(T, id: id);
    if (module != null) {
      return module;
    }
    final metadata = moduleMetadata[T];
    if (metadata == null) {
      throw StateError('Could not find metadata for module type $T');
    }
    if (metadata.lazyLoad) {
      module = metadata.factory(null);
    } else {
      throw StateError('Module $T not found');
    }
    _modules[Tuple2(T, id)] = module;
    await module._performLoad(
      system: system,
      scope: this,
    );
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
    } else if (!system.initializing) {
      throw StateError('Cannot use inject outside of load method');
    }
    final key = Tuple2(T, id);
    if (_modules.containsKey(key)) {
      throw StateError('Cannot inject $module: module already exists');
    }
    _modules[Tuple2(T, id)] = module;
    await module._performLoad(
      system: system,
      scope: this,
    );
  }

  Future<void> inject<T extends Module>(Module module, [Object id]) =>
      injectWith(T, module, id: id);

  void dispose() {
    for (final scope in children.values) {
      scope.dispose();
    }

    for (final module in modules.values) {
      module.dispose();
    }
  }
}
