import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';

import 'package:beeper/modules.dart';
import 'package:beeper/modules/discord.dart';
import 'package:beeper/modules/disposer.dart';
import 'package:beeper/gen/commands.g.dart';

class Command {
  final String name;
  final Set<String> alias;

  const Command({
    this.name,
    this.alias = const {},
  });
}

class CommandError {
  final String reason;

  const CommandError(this.reason);
}

typedef CommandFn = FutureOr<void> Function(CommandInvocation cmd);

class CommandEntry {
  Set<String> aliases;
  CommandFn fn;

  CommandEntry(this.aliases, this.fn);
}

class CommandArgs {
  final String text;

  final _wordPattern = RegExp('[a-zA-Z_][a-zA-Z_0-9]*');
  final _spacePattern = RegExp('[ \\r\\n\\t]+');
  final _notSpacePattern = RegExp('[^ \\r\\n\\t]+');
  final _intPattern = RegExp('(o[0-7]+|b[0-1]+|x[0-9A-Fa-f]+|[0-9]+)');

  CommandArgs(this.text) {
    int i = 0;

    String peek([int n = 1]) {
      if (i + n >= text.length) {
        return '';
      } else {
        return text.substring(i, i + n);
      }
    }

    String read([int n = 1]) {
      if (i + n >= text.length) {
        return null;
      } else {
        final out = text.substring(i, i + n);
        i += n;
        return out;
      }
    }

    String readPattern(RegExp pattern) {
      final match = pattern.matchAsPrefix(text, i);
      if (match == null) {
        return null;
      } else {
        i = match.end;
        return match.group(0);
      }
    }

    bool check(Pattern pattern) {
      final match = pattern.matchAsPrefix(text, i);
      if (match == null) {
        return false;
      } else {
        i = match.end;
        return true;
      }
    }

    void skipSpace() {
      readPattern(_spacePattern);
    }

    int readEscapedChar() {
      const escapeChars = {
        'a': '\x07',
        'b': '\b',
        'f': '\f',
        'n': '\n',
        'r': '\r',
        't': '\t',
        'v': '\v',
        '\\': '\\',
        '\'': '\'',
        '"': '"',
      };

      final firstChar = peek();
      if (escapeChars.containsKey(firstChar)) {
        return escapeChars[firstChar].codeUnitAt(0);
      }

      final match = readPattern(_intPattern);
      if (match == null) {
        return null;
      }

      final prefix = match.substring(0, 1);
      int result;
      if (prefix == 'x') {
        result = int.tryParse(match.substring(1), radix: 16);
      } else if (prefix == 'b') {
        result = int.tryParse(match.substring(1), radix: 2);
      } else if (prefix == 'o') {
        result = int.tryParse(match.substring(1), radix: 8);
      } else {
        result = int.tryParse(match);
      }

      if (result == null) {
        throw const CommandError('Parse error: Invalid escape sequence');
      }

      return result;
    }

    String readStringLiteral() {
      if (!check('"')) return null;

      var out = '';
      while (!check('"')) {
        final c = read();
        if (c == null) {
          throw const CommandError('Parse error: \'"\' expected before end of input');
        }
        if (c == '\\') {
          out += String.fromCharCode(readEscapedChar());
        } else {
          out += c;
        }
      }

      return out;
    }

    String readValue() {
      final str = readStringLiteral();
      if (str != null) {
        return str;
      }
      return readPattern(_notSpacePattern);
    }

    while (i != text.length) {
      skipSpace();
      final start = i;
      final name = readPattern(_wordPattern);
      if (name != null) {
        if (named.containsKey(name)) {
          throw const CommandError('Parse error: duplicate named argument');
        }
        skipSpace();
        if (check('=')) {
          skipSpace();
          final value = readValue();
          if (value == null) {
            throw const CommandError('Parse error: argument expected before end of input');
          }
          named[name] = value;
          continue;
        }
      }
      i = start;
      final value = readValue();
      if (value == null) {
        break;
      }
      positional.add(value);
    }
  }

  final positional = <String>[];
  final named = <String, String>{};
}

class CommandInvocation implements StreamSink<String>, StringSink {
  final CommandArgs args;
  final CommandEntry entry;
  final CommandsModule module;

  CommandInvocation({
    @required this.args,
    @required this.entry,
    @required this.module,
  }) {
    _controller.done.then((void value) => close());
  }

  final _controller = StreamController<String>.broadcast();

  String _result = '';

  String get result => _result;

  set result(String newResult) {
    _result = newResult;
    _controller.add(newResult);
  }

  @override
  void write(Object obj) {
    result += '$obj';
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    result += '${StringBuffer()..writeAll(objects, separator)}';
  }

  @override
  void writeCharCode(int charCode) {
    result += String.fromCharCode(charCode);
  }

  @override
  void writeln([Object obj = '']) {
    result += '$obj\n';
  }

  @override
  void add(String event) {
    result += event;
  }

  @override
  void addError(Object error, [StackTrace stackTrace]) {
    _controller.addError(error, stackTrace);
  }

  final _subscriptions = <StreamSubscription<String>>[];

  @override
  Future<void> addStream(Stream<String> stream) {
    final subscription = stream.listen(add);
    _subscriptions.add(subscription);
    return subscription.asFuture<void>();
  }

  final _closed = Completer<void>();

  bool get isDone => _closed.isCompleted;

  @override
  Future<void> get done => _closed.future;

  @override
  Future<void> close() async {
    if (_closed.isCompleted) {
      return;
    }

    _closed.complete();

    return Future.wait<void>([
      for (final subscription in _subscriptions)
        subscription.cancel(),
      _controller.close(),
    ]);
  }

  Future<void> call() async {
    await entry.fn(this);
    await close();
  }
}

@Metadata(name: 'commands', loadable: true)
class CommandsModule extends Module
  with Disposer, DiscordLoader, DatabaseLoader {

  final activeCommands = <String, CommandEntry>{};

  final _commandPattern = RegExp('([^ \\r\\n\\t]*)([\\s\\S]*)');

  void addEntry(CommandEntry entry) {
    for (final alias in entry.aliases) {
      if (!activeCommands.containsKey(alias)) {
        activeCommands[alias] = entry;
      }
    }
  }

  void removeEntry(CommandEntry entry) {
    for (final alias in entry.aliases) {
      if (activeCommands[alias] == entry) {
        activeCommands.remove(alias);
      }
    }
  }

  CommandInvocation createInvocation(String line) {
    final commandMatch = _commandPattern.matchAsPrefix(line);
    if (commandMatch == null) {
      return null;
    }
    final entry = activeCommands[commandMatch.group(1)];
    if (entry == null) {
      return null;
    }
    return CommandInvocation(
      args: CommandArgs(commandMatch.group(2)),
      entry: entry,
      module: this,
    );
  }

  @override
  Future<void> load() async {
    await super.load();

    queueDispose(discord.onMessageCreate.listen((message) async {
      if (message.user.bot) return;

      final prefixes = [
        '~',
        discord.user.mentionPattern,
      ];

      for (final prefix in prefixes) {
        final content = message.content.trim();
        final match = prefix.matchAsPrefix(content);
        if (match == null) {
          continue;
        }
        final invocation = createInvocation(
          content.substring(match.end).trimLeft()
        );
        if (invocation == null) {
          break;
        }

        try {
          await invocation.call();
          await message.reply(invocation.result);
        } catch (e, bt) {
          stderr.writeln('Error processing command in message ${message.id}');
          stderr.writeln(e);
          stderr.writeln(bt);
        }
      }
    }));
  }
}

mixin CommandsLoader on Module {
  CommandsModule commands;

  List<CommandEntry> _entries;

  @override
  Future<void> load() async {
    await super.load();
    commands = await scope.require();
    _entries = commandLoaders[runtimeType](this);
    _entries.forEach(commands.addEntry);
  }

  @override
  Future<void> unload() async {
    _entries.forEach(commands.removeEntry);
    await super.unload();
  }
}