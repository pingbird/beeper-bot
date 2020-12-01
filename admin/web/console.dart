import 'dart:async';
import 'dart:html';

import 'package:admin/client.dart';

void tabBarSetup() {
  final tabBar = querySelector('#tab-bar');
  final tabView = querySelector('#tab-view');
  for (var i = 0; i < tabBar.children.length; i++) {
    tabBar.children[i].onClick.listen((event) {
      for (var j = 0; j < tabBar.children.length; j++) {
        if (j == i) {
          tabView.children[j].classes.add('active');
          tabBar.children[j].classes.add('active');
        } else {
          tabView.children[j].classes.remove('active');
          tabBar.children[j].classes.remove('active');
        }
      }
    });
  }
}

String timeString(num dt) {
  const _rt = <String, double>{
    'millisecond': 0.001,
    'second': 1.0,
    'minute': 60.0,
    'hour': 3600.0,
    'day': 86400.0,
    'week': 604800.0,
    'month': 2629800.0,
  };

  const _wt = <String, int>{
    'millisecond': 1000,
    'second': 60,
    'minute': 60,
    'hour': 24,
    'day': 7,
    'week': 7,
    'month': 12,
  };

  if (dt == double.infinity) return 'never';
  if (dt == double.negativeInfinity) return 'forever ago';
  if (dt == double.nan) return 'unknown';

  var sr = '';
  if (dt < 0) {
    sr = 'in ';
    dt = dt.abs();
  }

  String c(String n) {
    final t = (dt / _rt[n]).floor() % _wt[n];
    return "$t $n${t != 1 ? "s" : ""}";
  }

  if (dt < 1) {
    return "$sr${c("millisecond")}";
  } else if (dt < 60) {
    return "$sr${c("second")}";
  } else if (dt < 3600) {
    return "$sr${c("minute")}";
  } else if (dt < 86400) {
    return "$sr${c("hour")}";
  } else if (dt < 604800) {
    return "$sr${c("day")}";
  } else if (dt < 2629800) {
    return "$sr${c("week")}";
  } else {
    return "$sr${c("month")}";
  }
}

void connectionSetup() async {
  void updateDiscordStatus(dynamic data) {
    final dynamic user = data['user'];
    if (user != null) {
      querySelector('#status-avatar').style.backgroundImage = 'url("${user['avatar']}")';
      querySelector('#status-name').text = '${user['name']}#${user['discriminator']}';
    }
  }

  void updateStatus(String module, dynamic data) {
    if (module == '/discord') {
      updateDiscordStatus(data);
    }
  }

  final connection = BeeperConnection(onStatusUpdate: updateStatus);
  Timer timer;

  final info = await connection.start(
    Uri.base.queryParameters['connect'] != null
      ? Uri.parse(Uri.base.queryParameters['connect'])
      : Uri(
        scheme: Uri.base.scheme == 'https' ? 'wss' : 'ws',
        host: Uri.base.host,
        path: '/ws',
      ),
  );

  void updateTime() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final started = info.started.millisecondsSinceEpoch;
    querySelector('#header-uptime').text = 'Up ${timeString((now - started) / 1000)}';
  }

  updateTime();
  timer?.cancel();
  timer = Timer.periodic(const Duration(seconds: 10), (timer) {
    updateTime();
  });

  querySelector('#header-version').text = info.version;
}

void main() {
  tabBarSetup();
  connectionSetup();
}