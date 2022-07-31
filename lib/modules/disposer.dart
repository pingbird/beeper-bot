import 'dart:async';

import 'package:beeper/modules.dart';

mixin Disposer on Module {
  final _objects = <Object>{};

  void queueDispose(Object object) {
    _objects.add(object);
  }

  @override
  Future<void> unload() async {
    for (final object in _objects) {
      if (object is StreamSubscription) {
        await object.cancel();
      } else {
        throw StateError(
            'Could not dispose object of type ${object.runtimeType}: Unknown type');
      }
    }
    _objects.clear();
    await super.unload();
  }
}
