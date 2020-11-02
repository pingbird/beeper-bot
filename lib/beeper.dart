import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:hotreloader/hotreloader.dart';

import 'package:beeper/discord/discord.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules.g.dart';

class Bot extends ModuleSystem {
  Discord discord;

  void start() async {
    final dynamic botConfig = loadYaml(await File('config/bot.yaml').readAsString());

    if (botConfig['development'] == true) {
      stderr.writeln('Hot reload started');
      await HotReloader.create(
        onAfterReload: (ctx) {
          stderr.writeln('Hot reload finished with ${ctx.result}');
        }
      );
    }

    scope = ModuleScope(system: this, parent: null);
    initializing = true;
    for (final config in botConfig['modules']) {
      final cantidates = moduleMetadata.entries.where((e) => e.value.name == config['type']);
      if (cantidates.isEmpty) {
        throw StateError('Could not find module with name "${config['type']}"');
      }
      final metadata = cantidates.single;
      final module = metadata.value.factory(config);
      await scope.injectWith(metadata.key, module, id: config['id']);
    }
    initializing = false;
  }
}