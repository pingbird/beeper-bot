import 'dart:async';

import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:analyzer/dart/element/element.dart';

import 'package:beeper/generators/common.dart';

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

    final imports = <LibraryElement, Set<String>>{};
    final out = StringBuffer();

    out.writeln('import \'package:beeper/modules/commands.dart\';');
    out.writeln('List<CommandEntry> get commandEntries => [');

    await for (final library in context.findLibs('lib/modules/**')) {
      final typeSystem = library.typeSystem;
      for (final cls in LibraryReader(library).classes) {
        final metadata = cls.getMetadata(metadataType);
        if (metadata == null) continue;
        if (!typeSystem.isSubtypeOf(cls.thisType, moduleType)) continue;

        for (final method in cls.methods) {
          final commandInfo = method.getMetadata(commandType);
          if (commandInfo == null) continue;
          imports.putIfAbsent(library, () => {});
          imports[library].add(cls.name);
          out.writeln(
            '  CommandEntry<${cls.name}>('
              'metadata: const ${objectEncode(commandInfo)}, '
              'extractor: (m) => m.${method.name}'
            ')'
          );
        }
      }
    }

    out.writeln('  ];');

    String importString(MapEntry<LibraryElement, Set<String>> entry) {
      return 'import \'${entry.key.librarySource.uri}\';\n';
    }

    context.output('commands', '${imports.entries.map(importString).join()}$out');
  }
}

Builder commandsBuilder(BuilderOptions options) => CommandsBuilder();
