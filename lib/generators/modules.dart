import 'dart:async';
import 'dart:io';

import 'package:source_gen/source_gen.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' show join;
import 'package:strings/strings.dart' show escape;
import 'package:dart_style/dart_style.dart' show DartFormatter;

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
    final formatter = DartFormatter();

    final labels = <String, String>{};
    final classes = <String, List<String>>{};

    final modulesLibrary = await buildStep.resolver.libraryFor(
      await buildStep.findAssets(Glob('lib/modules.dart')).single,
    );
    final moduleType = modulesLibrary.getType('Module').thisType;
    assert(moduleType != null);

    await for (final input in buildStep.findAssets(Glob('lib/modules/**'))) {
      final library = await buildStep.resolver.libraryFor(input);
      final typeSystem = library.typeSystem;
      final classesInLibrary = LibraryReader(library).classes;
      final classNames = <String>[];
      for (final cls in classesInLibrary) {
        if (!cls.isAbstract && typeSystem.isAssignableTo(cls.thisType, moduleType)) {
          assert(!labels.containsKey(cls.name));
          final labelField = cls.getField('label');
          if (labelField == null) {
            throw ArgumentError('${cls.name} does not have a label');
          } else if (!labelField.isStatic) {
            throw ArgumentError('${cls.name}.label is not static');
          }
          final label = labelField.computeConstantValue().toStringValue();
          labels[cls.name] = label;
          classNames.add(cls.name);
        }
      }
      if (classNames.isNotEmpty) {
        classes['${library.librarySource.uri}'] = classNames;
      }
    }

    final out = StringBuffer();

    out.writeln('import \'package:beeper/modules.dart\';');

    for (final libs in classes.entries) {
      out.writeln('import \'${escape(libs.key)}\' show ${libs.value.join(', ')};');
    }

    out.writeln('final moduleMetadata = {');

    for (final libs in classes.entries) {
      for (final cls in libs.value) {
        out.writeln(
          '$cls: ModuleMetadata('
          'label:\'${escape(labels[cls])}\','
          'factory: () => $cls()),'
        );
      }
    }

    out.writeln('};');

    String formatted = '$out';
    try {
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
