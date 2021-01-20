import 'dart:async';

import 'package:beeper/generators/common.dart';
import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:strings/strings.dart' show escape;
import 'package:analyzer/dart/element/element.dart';

class ModulesBuilder extends AggregateBuilder {
  @override
  List<String> get outputs => ['modules'];

  @override
  Future<void> buildAggregate(AggregateContext context) async {
    final modulesLibrary = await context.findLibs('lib/modules.dart').single;
    final metadataType = modulesLibrary.getType('Metadata').thisType;
    final moduleType = modulesLibrary.getType('Module').thisType;

    final libs = <LibraryElement, List<ClassElement>>{};

    await for (final library in context.findLibs('lib/modules/**')) {
      final typeSystem = library.typeSystem;
      final classElements = <ClassElement>[];
      for (final cls in LibraryReader(library).classes) {
        if (!cls.isAbstract && typeSystem.isAssignableTo(cls.thisType, moduleType)) {
          classElements.add(cls);
        }
      }
      if (classElements.isNotEmpty) {
        libs[library] = classElements;
      }
    }

    final out = StringBuffer();

    out.writeln('import \'package:beeper/modules.dart\';');

    for (final lib in libs.entries) {
      out.writeln(
        'import \'${escape('${lib.key.source.uri}')}\' '
        'show ${lib.value.map((e) => e.name).join(', ')};'
      );
    }

    out.writeln('Map<Type, Metadata> get moduleMetadata => {');

    for (final cls in libs.entries.expand((l) => l.value)) {
      final name = cls.name;

      final metadata = cls.getMetadata(metadataType);
      if (metadata == null) {
        throw StateError('Module ${cls.name} from ${cls.library.source} does not have metadata');
      } else if (cls.unnamedConstructor == null) {
        throw StateError('Module ${cls.name} from ${cls.library.source} does not have a default constructor');
      }
      final ctorArgs = cls.unnamedConstructor.parameters;

      final args = <String>[];
      var lazyLoad = metadata.getField('lazyLoad').toBoolValue();

      if (ctorArgs.length == 1 && ctorArgs.first.type.isDynamic) {
        args.add('data');
      } else if (lazyLoad != false) {
        for (final arg in ctorArgs) {
          if (!arg.isNamed) {
            throw StateError('Constructor of module ${cls.name} from ${cls.library.source} has an un-named argument "${arg.name}"');
          }
          args.add('${arg.name}: data[\'${arg.name}\'] as ${arg.type.getDisplayString(withNullability: false)}');
        }
      }

      lazyLoad ??= true;

      out.writeln(
        '$name: Metadata('
        'name: \'${escape(metadata.getField('name').toStringValue())}\', '
        'lazyLoad: $lazyLoad, ' + (
          lazyLoad
            ? 'factory: (dynamic data) => $name(${args.join(', ')})),'
            : 'factory: null),'
        )
      );
    }

    out.writeln('};\n');

    for (final lib in libs.entries) {
      final reader = LibraryReader(lib.key);
      for (final cls in lib.value) {
        final name = cls.name;
        if (!name.endsWith('Module')) {
          continue;
        }

        final metadata = cls.getMetadata(metadataType);
        if (!metadata.getField('loadable').toBoolValue()) {
          continue;
        }

        final mixinName = '${name}Loader'.replaceAll('ModuleLoader', 'Loader');
        if (reader.findType(mixinName) != null) {
          continue;
        }

        final varName =
          mixinName.substring(0, 1).toLowerCase()
          + mixinName.substring(1, mixinName.length - 'Loader'.length);
        out.writeln(
          'mixin $mixinName on Module {\n'
          '  $name $varName;\n\n'
          '  @override\n'
          '  Future<void> load() async {\n'
          '    await super.load();\n'
          '    $varName = await scope.require();\n'
          '  }\n'
          '}\n'
        );
      }
    }

    context.output('modules', '$out');
  }
}

Builder modulesBuilder(BuilderOptions options) => ModulesBuilder();
