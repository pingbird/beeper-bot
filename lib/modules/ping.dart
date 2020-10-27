import 'package:beeper/modules.dart';
import 'package:beeper/modules/commands.dart';

class PingMod extends Module with CommandReceiver {
  static const label = 'ping';

  @override
  Future<void> load() async {
    await super.load();
  }
}