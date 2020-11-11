import 'package:beeper/modules/ping.dart';
import 'package:beeper/modules/commands.dart';

List<CommandEntry> get commandEntries => [
      CommandEntry<PingModule>(metadata: const Command(alias: {'p'}), extractor: (m) => m.ping)
    ];
