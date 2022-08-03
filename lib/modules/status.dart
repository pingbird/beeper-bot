import 'dart:async';

import 'package:beeper/modules.dart';
import 'package:beeper_common/logging.dart';
import 'package:collection/collection.dart';

class StatusUpdateEvent {
  final Module module;
  final dynamic data;

  StatusUpdateEvent({
    required this.module,
    required this.data,
  });
}

@Metadata(name: 'status', lazyLoad: false)
class StatusModule extends Module {
  final Stream<LogEvent> events;

  StatusModule(this.events);

  final _updateController = StreamController<StatusUpdateEvent>.broadcast();

  Stream<StatusUpdateEvent> get updates => _updateController.stream;

  Map<String, dynamic> getStatuses() {
    final statuses = <String, dynamic>{};

    void add(Module m) {
      if (m is StatusLoader) {
        statuses[m.canonicalName] = m._status;
      }
    }

    void visit(ModuleScope s) {
      s.modules.values.forEach(add);
      s.children.values.forEach(visit);
    }

    visit(system.scope);

    return statuses;
  }
}

mixin StatusLoader on Module {
  late final StatusModule statusModule;
  Object? _status;
  bool _loaded = false;

  dynamic get status => _status;
  set status(dynamic data) {
    if (const DeepCollectionEquality().equals(data, _status) || !_loaded) {
      return;
    }

    _status = data;
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

  void log(String content, {LogLevel level = LogLevel.info}) {
    logger.log(canonicalName, content, level: level);
  }
}
