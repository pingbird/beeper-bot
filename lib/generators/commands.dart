import 'dart:async';

import 'package:beeper/generators/common.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';

class CommandsBuilder extends AggregateBuilder {
  @override
  List<String> get outputs => ['commands'];

  @override
  Future<void> buildAggregate(AggregateContext context) async {
    final commandsLibrary = await context.findLibs('lib/modules/commands.dart').single;
    final commandType = commandsLibrary.getType('Command').thisType;
    final modulesLibrary = await context.findLibs('lib/modules.dart').single;
    final moduleType = modulesLibrary.getType('Module').thisType;
    final metadataType = modulesLibrary.getType('Metadata').thisType;

    final out = StringBuffer();

    out.writeln('final commandEntries = {');

    await for (final library in context.findLibs('lib/modules/**')) {
      final typeSystem = library.typeSystem;
      for (final cls in LibraryReader(library).classes) {
        final metadata = cls.getMetadata(metadataType);
        if (metadata == null) continue;
        if (!typeSystem.isSubtypeOf(cls.thisType, moduleType)) continue;

        out.writeln('  \'${metadata.getField('name').toStringValue()}\': CommandEntry(),');

        for (final method in cls.methods) {
          final commandInfo = method.getMetadata(commandType);
        }
      }
    }

    out.writeln('};');

    context.output('commands', '$out');
  }
}

Builder commandsBuilder(BuilderOptions options) => CommandsBuilder();
