import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart' show CommandsMod;
import 'package:beeper/modules/ping.dart' show PingMod;

final moduleMetadata = {
  CommandsMod: ModuleMetadata(label: 'commands', factory: () => CommandsMod()),
  PingMod: ModuleMetadata(label: 'ping', factory: () => PingMod()),
};
