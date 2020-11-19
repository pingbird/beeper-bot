import 'dart:async';

import 'package:meta/meta.dart';

import 'package:beeper/modules.dart';

class StatusUpdateEvent {
  final Module module;
  final dynamic data;

  StatusUpdateEvent({
    @required this.module,
    @required this.data,
  });
}

@Metadata(name: 'status', loadable: true)
class StatusModule extends Module {
  final _updateController = StreamController<StatusUpdateEvent>.broadcast();
  Stream<StatusUpdateEvent> get updates => _updateController.stream;
}

mixin StatusLoader on Module {
  StatusModule statusModule;
  dynamic _status;
  bool _loaded = false;

  dynamic get status => _status;
  set status(dynamic data) {
    if (data == _status || !_loaded) return;
    statusModule._updateController.add(
      StatusUpdateEvent(
        module: this,
        data: data,
      ),
    );
  }

  @override
  Future<void> load() async {
    await super.load();
    statusModule = await scope.require();
    if (_status != null) {
      statusModule._updateController.add(
        StatusUpdateEvent(
          module: this,
          data: status,
        ),
      );
    }
    _loaded = true;
  }

  @override
  Future<void> unload() async {
    await super.unload();
    if (_status != null) {
      statusModule._updateController.add(
        StatusUpdateEvent(
          module: this,
          data: null,
        ),
      );
    }
    _loaded = false;
  }
}