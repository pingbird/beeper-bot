import 'package:beeper/beeper.dart';
import 'package:beeper/modules.dart';

class CommandsMod extends Module {
  static const label = 'commands';
}

mixin CommandReceiver on Module {
  CommandsMod commands;

  @override
  Future<void> load() async {
    await super.load();
    commands = await bot.require();
  }
}