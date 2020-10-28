import 'package:beeper/beeper.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules/disposer.dart';

class CommandsMod extends Module with Disposer {
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