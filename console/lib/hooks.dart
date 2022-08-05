import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extensions that allow Consumer widget create concise ChangeNotifier, Future,
/// and Stream hooks.
///
/// Hooks are identified by a key object e.g. `#myFutureName`, if the widget
/// re-builds without calling the hook again, it is automatically disposed.
extension RefHookExtensions on WidgetRef {
  /// Lazily initializes a ChangeNotifier which can re-build the current widget.
  ///
  /// This method dynamically creates a [ChangeNotifierProvider] to notify the
  /// widget to rebuild and know when to dispose the hook.
  ///
  /// If [watch] is false the widget will keep the [ChangeNotifier] alive, but
  /// won't re-build when it changes.
  T useNotifier<T extends ChangeNotifier>(
    Object key,
    T Function() create, {
    bool watch = true,
  }) {
    // Lazily create a _HookManager, this uses an Expando so it should be
    // automatically garbage collected after the widget is disposed
    final manager = _HookManager.managers[this] ??= _HookManager();

    var hook = manager.hooks[key];
    var notifier = hook?.notifier;
    if (notifier is! T) {
      // Dispose the existing hook if it's a different notifier type
      hook?.notifier.dispose();

      notifier = create();
      hook = _Hook(
        notifier,
        ChangeNotifierProvider.autoDispose((ref) {
          ref.onDispose(() {
            manager.hooks.remove(key);
          });
          return notifier!;
        }),
      );
      manager.hooks[key] = hook;
    }
    if (watch) {
      this.watch<void>(hook!.provider);
    } else {
      listen<void>(hook!.provider, (_, __) {});
    }
    return notifier;
  }

  /// Starts a future and returns a [Task] that tracks the state of it, should
  /// only be called in `build` or `didChangeDependencies'.
  ///
  /// [key] is used to identify the task, it is typically a constant [Symbol]
  /// value e.g. `#myFuture`.
  ///
  /// [create] will be called if any of the following conditions are true:
  /// 1. This method is called for the first time with a particular [key]
  /// 2. [dependencies] changes according to [DeepCollectionEquality]
  /// 3. [Task.restart] is called
  /// 4. The generic type was different from the previous build
  ///
  /// When [dependencies] changes, [retain] is used to determine if the existing
  /// [Task.value] / [Task.error] should be retained, else if [retain] is false
  /// they are cleared as if we called this method for the first time.
  ///
  /// If [enabled] is false, the [create] method will no longer be called,
  /// this is useful if you want to hold off on starting a future until some
  /// other data is available first.
  Task<T> useFuture<T>(
    Object key,
    Future<T> Function() create, {
    bool watch = true,
    Object? dependencies,
    bool retain = false,
    bool enabled = true,
    void Function(Object error, StackTrace stackTrace) onError =
        Task.defaultErrorHandler,
  }) {
    final task = useNotifier<_TaskImpl<T>>(key, _TaskImpl.new, watch: watch);
    task.createFn = () => create().asStream();
    task.update(dependencies, retain, false, enabled, onError);
    return task;
  }

  /// Like [useFuture] but listens to a [Stream] instead of a [Future].
  ///
  /// To prevent any loss in data, the stream returned from [create] should
  /// single-subscription, if you are sharing data between widgets consider
  /// using a [BehaviorSubject] instead of [StreamController.broadcast].
  ///
  /// If [pause] is true, the managed [StreamSubscription] is paused.
  Task<T> useStream<T>(
    Object key,
    Stream<T> Function() create, {
    bool watch = true,
    Object? dependencies,
    bool retain = false,
    bool pause = false,
    bool enabled = true,
    void Function(Object error, StackTrace stackTrace) onError =
        Task.defaultErrorHandler,
  }) {
    final task = useNotifier<_TaskImpl<T>>(key, _TaskImpl.new, watch: watch);
    task.createFn = create;
    task.update(dependencies, retain, pause, enabled, onError);
    return task;
  }
}

class _Hook {
  _Hook(this.notifier, this.provider);

  final ChangeNotifier notifier;
  final ProviderBase provider;
}

class _HookManager {
  /// We use an [Expando] to attach state to a [WidgetRef], otherwise there
  /// would be no way to guarantee that hooks are garbage collected.
  static final managers = Expando<_HookManager>();
  final hooks = <Object, _Hook>{};
}

/// A running asynchronous task that can be restarted.
abstract class Task<T> extends ChangeNotifier {
  /// Whether or not the task is loading, i.e. has not completed with a value
  /// or error.
  bool get isLoading;

  /// Whether or not the stream has closed.
  bool get isClosed;

  /// Whether or not a value is ready.
  bool get hasValue;

  /// The last emitted value, or null if the task is still loading.
  T? get value;

  /// The last emitted error, or null if there was no error.
  Object? get error;

  /// Whether or not the task completed with an error.
  bool get hasError => error != null;

  /// The stack trace of the [error], if any.
  StackTrace? get stackTrace;

  /// Restarts an existing task, useful for pull-to-refresh behavior.
  ///
  /// [retain] is used to determine if the existing [value] / [error] should be
  /// retained, else if [retain] is false they are cleared as if we started this
  /// task for the first time.
  ///
  /// If [force] is true then the task is restarted regardless of whether or not
  /// it's enabled.
  void restart({
    bool retain = false,
    bool force = false,
  });

  static void defaultErrorHandler(Object error, StackTrace stackTrace) {
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'dub',
      ),
    );
  }

  R match<R>({
    R Function()? loading,
    required R Function(T? value) builder,
    R Function(Object exception, StackTrace? stackTrace)? error,
    R Function()? closed,
  }) {
    if (hasError && error != null) {
      return error(this.error!, stackTrace);
    }

    if (isClosed && closed != null) {
      return closed();
    }

    if (isLoading && loading != null) {
      return loading();
    }

    return builder(value);
  }
}

class _TaskImpl<T> extends Task<T> {
  Stream<T> Function()? createFn;

  @override
  bool isLoading = true;

  @override
  bool isClosed = false;

  @override
  Object? error;

  @override
  var hasValue = false;

  @override
  StackTrace? stackTrace;

  @override
  T? value;

  StreamSubscription? _subscription;
  Object? _dependencies;
  bool _firstUpdate = true;
  bool _enabled = false;
  bool _disposed = false;
  void Function(Object error, StackTrace stackTrace)? _onError;

  void update(
    Object? newDependencies,
    bool retain,
    bool pause,
    bool enabled,
    void Function(Object error, StackTrace stackTrace) onError,
  ) {
    _enabled = enabled;
    _onError = onError;
    if (enabled) {
      // Start the stream if we haven't already
      if (_firstUpdate) {
        _firstUpdate = false;
        restart(
          retain: true,
          duringBuild: true,
        );
      } else if (!const DeepCollectionEquality()
          .equals(_dependencies, newDependencies)) {
        _dependencies = newDependencies;
        restart(
          retain: retain,
          duringBuild: true,
        );
      }
    }

    // Manage the subscription
    if (_subscription != null) {
      if (pause && !_subscription!.isPaused) {
        _subscription!.pause();
      } else if (!pause && _subscription!.isPaused) {
        _subscription!.resume();
      }
    }
  }

  @override
  void restart({
    bool retain = false,
    bool force = false,
    bool duringBuild = false,
  }) {
    if (_disposed || (!_enabled && !force)) {
      return;
    }

    // Clear value and error unless we want them to be retained, avoid calling
    // notifyListeners if nothing has changed
    if (!retain && (hasValue || hasError || !isLoading)) {
      value = null;
      hasValue = false;
      error = null;
      stackTrace = null;
      isLoading = true;
      if (!duringBuild) notifyListeners();
    }

    // Cancel existing subscription and set it to null in case fn throws an
    // exception
    _subscription?.cancel();
    _subscription = null;

    Stream<T> stream;
    try {
      stream = createFn!();
      _subscription = stream.listen(
        (event) {
          hasValue = true;
          value = event;
          error = null;
          stackTrace = null;
          isLoading = false;
          notifyListeners();
        },
        onError: (Object error, StackTrace stackTrace) {
          this.error = error;
          this.stackTrace = stackTrace;
          isLoading = false;
          if (_onError != null) _onError!(error, stackTrace);
          notifyListeners();
        },
        onDone: () {
          if (isLoading || !isClosed) {
            isLoading = false;
            isClosed = true;
            notifyListeners();
          }
        },
      );
    } catch (error, stackTrace) {
      // createFn can throw synchronously, just treat it as if the error came
      // from the Stream
      if (_onError != null) _onError!(error, stackTrace);
      this.error = error;
      this.stackTrace = stackTrace;
      isLoading = false;
      if (!duringBuild) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
