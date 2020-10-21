import 'package:beeper/beeper.dart';
import 'package:beeper/modules/commands.dart';

class PingMod extends Module with CommandReceiver {
  static const label = 'ping';
}