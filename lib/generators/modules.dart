import 'dart:async';
import 'dart:io';

import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' show join;
import 'package:strings/strings.dart' show escape;
import 'package:dart_style/dart_style.dart' show DartFormatter;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/constant/value.dart';

class ModuleFactoryBuilder extends Builder {
  @override
  final buildExtensions = const {
    r'$lib$': ['modules.g.dart']
  };

  static AssetId _allFileOutput(BuildStep buildStep) {
    return AssetId(
      buildStep.inputId.package,
      join('lib', 'modules.g.dart'),
    );
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    final modulesLibrary = await buildStep.resolver.libraryFor(
      await buildStep.findAssets(Glob('lib/modules.dart')).single,
    );
    final metadataType = modulesLibrary.getType('Metadata').thisType;
    final moduleType = modulesLibrary.getType('Module').thisType;
    assert(moduleType != null);

    final libs = <LibraryElement, List<ClassElement>>{};

    await for (final input in buildStep.findAssets(Glob('lib/modules/**'))) {
      final library = await buildStep.resolver.libraryFor(input);
      final typeSystem = library.typeSystem;
      final classesInLibrary = LibraryReader(library).classes;
      final classElements = <ClassElement>[];
      for (final cls in classesInLibrary) {
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

    out.writeln('final moduleMetadata = {');

    for (final cls in libs.entries.expand((l) => l.value)) {
      final name = cls.name;
      final typeSystem = cls.library.typeSystem;

      DartObject metadata;
      for (final element in cls.metadata) {
        final value = element.computeConstantValue();
        if (typeSystem.isAssignableTo(value.type, metadataType)) {
          metadata = value;
          break;
        }
      }
      assert(metadata != null, 'Module ${cls.name} from ${cls.library.source} does not have metadata');

      assert(cls.unnamedConstructor != null, 'Module ${cls.name} from ${cls.library.source} does not have a default constructor');
      final ctorArgs = cls.unnamedConstructor.parameters;

      var args = <String>[];
      var lazyLoad = metadata.getField('lazyLoad').toBoolValue();

      if (ctorArgs.isEmpty) {
        lazyLoad ??= true;
      } else if (ctorArgs.length == 1 && ctorArgs.first.type.isDynamic) {
        args.add('data');
      } else {
        for (final arg in ctorArgs) {
          assert(arg.isNamed, 'Constructor of module ${cls.name} from ${cls.library.source} has an un-named argument "${arg.name}"');
          args.add('${arg.name}: data[\'${arg.name}\'] as ${arg.type.getDisplayString(withNullability: false)}');
        }
      }

      out.writeln(
        '$name: Metadata('
        'name: \'${escape(metadata.getField('name').toStringValue())}\', '
        'lazyLoad: ${lazyLoad ?? false}, '
        'factory: (dynamic data) => $name(${args.join(', ')})),'
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

    String formatted = '$out';
    try {
      final formatter = DartFormatter(
        pageWidth: 1024,
      );
      formatted = formatter.format(formatted);
    } catch (e, bt) {
      stderr.writeln('Formatting failed with: $e\n$bt');
    }

    await buildStep.writeAsString(
      _allFileOutput(buildStep),
      formatted,
    );
  }
}

Builder moduleFactoryBuilder(BuilderOptions options) => ModuleFactoryBuilder();
