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
      final metadata = moduleMetadata.entries.singleWhere((e) => e.value.label == config['type']);
      if (metadata == null) {
        throw StateError('Could not find module of type "${config['type']}"');
      }
      await scope.injectWith(metadata.key, metadata.value.factory(), config['id']);
    }
    initializing = false;
  }
}