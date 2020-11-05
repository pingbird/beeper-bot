import 'dart:io';

import 'package:meta/meta.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' show join;
import 'package:dart_style/dart_style.dart' show DartFormatter;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';

class AggregateContext {
  final AggregateBuilder builder;
  final BuildStep buildStep;

  AggregateContext({
    @required this.builder,
    @required this.buildStep,
  });

  Future<void> output(String name, String contents) {
    try {
      final formatter = DartFormatter(
        pageWidth: 1024,
      );
      contents = formatter.format(contents);
    } catch (e, bt) {
      stderr.writeln('Formatting failed with: $e\n$bt');
    }

    final assetId = AssetId(
      buildStep.inputId.package,
      join('lib', 'gen/$name.g.dart'),
    );

    return buildStep.writeAsString(assetId, contents);
  }

  Stream<LibraryElement> findLibs(String glob) async* {
    await for (final input in buildStep.findAssets(Glob(glob))) {
      yield await buildStep.resolver.libraryFor(input);
    }
  }
}

extension ElementExtension on Element {
  DartObject getMetadata(DartType type) {
    for (final data in metadata) {
      final value = data.computeConstantValue();
      if (library.typeSystem.isSubtypeOf(value.type, type)) {
        return value;
      }
    }
    return null;
  }
}

abstract class AggregateBuilder extends Builder {
  List<String> get outputs;

  @override
  Map<String, List<String>> get buildExtensions => {
    r'$lib$': [
      for (final output in outputs) 'gen/$output.g.dart'
    ]
  };

  Future<void> buildAggregate(AggregateContext context);

  @override
  Future<void> build(BuildStep buildStep) async {
    await buildAggregate(AggregateContext(builder: this, buildStep: buildStep));
  }
}