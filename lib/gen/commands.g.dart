import 'package:beeper/modules/ping.dart';
// ignore_for_file: directives_ordering
import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart';

Map<Type, List<CommandEntry> Function(Module module)> get commandLoaders => {
      PingModule: (Module module) {
        final m = module as PingModule;
        return [
          CommandEntry({'p', 'ping'}, m.ping),
        ];
      },
    };
