import 'dart:async';
import 'dart:io';

import 'package:yaml/yaml.dart';
import 'package:meta/meta.dart';
import 'package:hotreloader/hotreloader.dart';

import 'package:beeper_common/logging.dart';
import 'package:beeper/modules.dart';
import 'package:beeper/modules/status.dart';

extension ModuleBotExtension on Module {
  Bot get bot => system as Bot;
}

class Bot extends ModuleSystem {
  String version;

  dynamic config;

  Bot({@required this.config}) {
    logger = Logger((e) {
      if (e.level.index >= LogLevel.warning.index) {
        stderr.writeln(e);
      } else {
        stdout.writeln(e);
      }
      _logEvents.add(e);
    });
  }

  Logger logger;
  final _logEvents = StreamController<LogEvent>.broadcast();

  Future<void> start() async {
    if (config['version'] != null) {
      version = config['version'] as String;
    } else {
      try {
        final result = await Process.run('git', ['rev-parse', '--short', 'HEAD']);
        version = result.stdout.toString().trim();
        if (version.isEmpty) {
          version = 'unknown';
        }
      } catch (e) {
        version = 'unknown';
      }
    }

    if (config['development'] == true) {
      logger.log('bot', 'Hot reload started');
      await HotReloader.create(
        onAfterReload: (ctx) {
          logger.log('bot', 'Hot reload finished with ${ctx.result}');
        }
      );
    }

    scope = ModuleScope(system: this, parent: null);

    reconfigure();
  }

  void reconfigure() async {
    assert(initializing == false);
    initializing = true;

    await logger.wrap(() async {
      scope.inject<StatusModule>(StatusModule(_logEvents.stream));

      for (final config in config['modules']) {
        final candidates = moduleMetadata.entries.where((e) => e.value.name == config['type']);
        if (candidates.isEmpty) {
          throw StateError('Could not find module with name "${config['type']}"');
        }
        final metadata = candidates.single;
        if (!metadata.value.lazyLoad) {
          throw StateError('Attempted to load module from config that cannot be lazy-loaded: "${metadata.value.name}"');
        }
        final module = metadata.value.factory(config);
        await scope.injectWith(metadata.key, module, id: config['id']);
      }
    });

    initializing = false;
  }

  static Future<Bot> fromFile(File file) async {
    final configStat = file.statSync();

    if (configStat.type != FileSystemEntityType.file) {
      throw Exception('Configuration file config/bot.yaml not found or of wrong type');
    } else if (!Platform.isWindows && configStat.mode & 7 != 0) {
      throw Exception('Configuration file is accessible to outside users, mode 660 is recommended');
    }

    return Bot(config: loadYaml(await file.readAsString()));
  }

  void dispose() {
    scope.dispose();
  }
}