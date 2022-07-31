import 'dart:async';

enum LogLevel {
  verbose,
  info,
  warning,
  error,
}

class LogEvent {
  final DateTime time;
  final LogLevel level;
  final String name;
  final String content;

  LogEvent(this.time, this.level, this.name, this.content);

  factory LogEvent.fromJson(dynamic data) {
    return LogEvent(
      DateTime.fromMillisecondsSinceEpoch(data['time'] as int),
      LogLevel.values[data['level'] as int],
      data['name'] as String,
      data['content'] as String,
    );
  }

  @override
  String toString() {
    const levels = ['V', 'I', 'W', 'E'];
    return '${levels[level.index]} [$name] $content';
  }

  dynamic toJson() {
    return <String, dynamic>{
      'time': time.millisecondsSinceEpoch,
      'level': level.index,
      'name': name,
      'content': content,
    };
  }
}

final _loggerKey = Object();
Logger get logger => Zone.current[_loggerKey] as Logger;

class Logger {
  final void Function(LogEvent event) onEvent;

  Logger(this.onEvent);

  void log(String name, String content, {DateTime? time, LogLevel? level}) {
    onEvent(
      LogEvent(
        time ?? DateTime.now(),
        level ?? LogLevel.info,
        name,
        content,
      ),
    );
  }

  T? wrap<T>(T Function() fn) => runZonedGuarded(
        fn,
        (e, bt) {
          log('exception', '$e\n$bt', level: LogLevel.error);
        },
        zoneValues: {
          _loggerKey: this,
        },
      );
}
