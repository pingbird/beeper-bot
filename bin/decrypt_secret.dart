import 'dart:io';

import 'package:beeper/secrets.dart';

int main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln('Error: Exactly 2 arguments expected');
    return 1;
  }

  print(decryptSecret(args[0], args[1]));

  return 0;
}