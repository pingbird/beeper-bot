import 'dart:async';
import 'dart:io';

import 'package:beeper/beeper.dart';
import 'package:stack_trace/stack_trace.dart';

void main(List<String> arguments) {
  runZonedGuarded(() {
    Chain.capture(() async {
      final bot = await Bot.fromFile(File('config/bot.yaml'));
      bot.start();
    });
  }, (e, bt) {
    stderr.writeln('Uncaught exception');
    stderr.writeln('$e\n$bt');
  });
}
