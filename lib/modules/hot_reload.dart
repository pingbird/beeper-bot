import 'package:beeper/modules.dart';
import 'package:beeper/modules/status.dart';
import 'package:beeper_common/logging.dart';
import 'package:hotreloader/hotreloader.dart';

@Metadata(name: 'hot_reload')
class HotReloadModule extends Module with StatusLoader {
  HotReloader hotReloader;
  @override
  Future<void> load() async {
    await super.load();
    await HotReloader.create(onAfterReload: (ctx) {
      for (final e in ctx.events) {
        logger.log(
          'hot_reload',
          '${const {
            'add': '+',
            'remove': '-',
            'modify': '*',
          }[e.type.toString()]}${e.path}',
        );
      }

      switch (ctx.result) {
        case HotReloadResult.Skipped:
          break;
        case HotReloadResult.Failed:
          logger.log('hot_reload', 'Hot reload failed');
          break;
        case HotReloadResult.PartiallySucceeded:
          logger.log('hot_reload', 'Partial hot reload successful');
          break;
        case HotReloadResult.Succeeded:
          logger.log('hot_reload', 'Hot reload successful');
          break;
      }
    });
    logger.log('hot_reload', 'Hot reload started');
  }

  @override
  Future<void> unload() async {
    await hotReloader.stop();
    return super.unload();
  }
}
