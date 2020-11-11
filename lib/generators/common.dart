import 'dart:io';

import 'package:meta/meta.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' show join;
import 'package:dart_style/dart_style.dart' show DartFormatter;
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:strings/strings.dart' show escape;

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

/// Encodes a DartObject into dart code, only supports a limited number of types.
String objectEncode(DartObject value) {
  final type = value.type;
  if (type.isDartCoreNull) {
    return 'null';
  } else if (type.isDartCoreString) {
    return '\'${escape(value.toStringValue())}\'';
  } else if (type.isDartCoreInt) {
    return '${value.toIntValue()}';
  } else if (type.isDartCoreDouble) {
    return '${value.toDoubleValue()}';
  } else if (type.isDartCoreBool) {
    return '${value.toBoolValue()}';
  } else if (type.isDartCoreSet) {
    return '{${value.toSetValue().map(objectEncode).join(', ')}}';
  } else if (type.isDartCoreList) {
    return '[${value.toListValue().map(objectEncode).join(', ')}]';
  } else if (type.isDartCoreMap) {
    return '{${value.toMapValue().entries.map((e) => '${objectEncode(e.key)}: ${objectEncode(e.value)}').join(', ')}';
  } else if (type.isDartCoreSymbol) {
    return '#${value.toSymbolValue()}';
  } else if (type is InterfaceType) {
    final args = <String>[];
    final ctor = type.element.unnamedConstructor;
    for (final arg in ctor.parameters) {
      final argValue = value.getField(arg.name);
      if (arg.isNamed && arg.computeConstantValue() != argValue) {
        args.add('${arg.name}: ${objectEncode(argValue)}');
      } else if ((arg.isOptional && arg.computeConstantValue() != argValue) || !arg.isOptional) {
        args.add('${objectEncode(argValue)}');
      }
    }
    return '${type.element.name}(${args.join(', ')})';
  } else {
    throw ArgumentError('Cannot encode object of type $type');
  }
}