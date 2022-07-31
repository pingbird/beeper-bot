import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:beeper/generators/common.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:strings/strings.dart';

class CommandsBuilder extends AggregateBuilder {
  @override
  List<String> get outputs => ['commands'];

  @override
  Future<void> buildAggregate(AggregateContext context) async {
    final commandsLibrary =
        await context.findLibs('lib/modules/commands.dart').single;
    final commandType = commandsLibrary.getType('Command').thisType;
    final modulesLibrary = await context.findLibs('lib/modules.dart').single;
    final moduleType = modulesLibrary.getType('Module').thisType;
    final metadataType = modulesLibrary.getType('Metadata').thisType;

    final imports = <LibraryElement, Set<String>>{};
    final out = StringBuffer();

    out.writeln('import \'package:beeper/modules.dart\';');
    out.writeln('import \'package:beeper/modules/commands.dart\';');
    out.writeln(
        'Map<Type, List<CommandEntry> Function(Module module)> get commandLoaders => {');

    await for (final library in context.findLibs('lib/modules/**')) {
      final typeSystem = library.typeSystem;
      for (final cls in LibraryReader(library).classes) {
        final metadata = cls.getMetadata(metadataType);
        if (metadata == null) continue;
        if (!typeSystem.isSubtypeOf(cls.thisType, moduleType)) continue;

        final entries = <String>[];

        for (final method in cls.methods) {
          final commandInfo = method.getMetadata(commandType);
          if (commandInfo == null) continue;
          imports.putIfAbsent(library, () => {});
          imports[library].add(cls.name);

          final commandName = commandInfo.getField('name').isNull
              ? method.name
              : commandInfo.getField('name').toStringValue();

          final commandAliases = commandInfo.getField('alias').isNull
              ? <String>{}
              : commandInfo
                  .getField('alias')
                  .toSetValue()
                  .map(
                    (s) => s.toStringValue(),
                  )
                  .toSet();

          commandAliases.add(commandName);

          entries.add('CommandEntry('
              '{${commandAliases.map((s) => '\'${escape(s)}\'').join(', ')}},'
              'm.${method.name}'
              ')');
        }

        if (entries.isNotEmpty) {
          out.writeln('  ${cls.name}: (Module module) {\n'
              '    final m = module as ${cls.name};\n'
              '    return [\n'
              '      ${entries.join(',\n      ')},\n'
              '    ];\n'
              '  },');
        }
      }
    }

    out.writeln('};');

    String importString(MapEntry<LibraryElement, Set<String>> entry) {
      return 'import \'${entry.key.librarySource.uri}\';\n';
    }

    context.output(
      'commands',
      '// ignore_for_file: directives_ordering\n'
          '${imports.entries.map(importString).join()}$out',
    );
  }
}

Builder commandsBuilder(BuilderOptions options) => CommandsBuilder();
