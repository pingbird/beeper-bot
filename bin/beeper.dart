import 'package:beeper/beeper.dart';
import 'package:stack_trace/stack_trace.dart';

void main(List<String> arguments) {
  Chain.capture(() {
    Bot().start();
  });
}
