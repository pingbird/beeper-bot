import 'dart:async';
import 'dart:html' as html;

import 'package:admin2/pages/status.dart';
import 'package:admin2/tabs.dart';
import 'package:beeper_common/admin.dart';
import 'package:beeper_common/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../connection.dart';

class ConsolePage extends StatefulWidget {
  const ConsolePage({Key? key}) : super(key: key);

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage>
    with TickerProviderStateMixin {
  late final controller = TabController(
    length: 3,
    vsync: this,
  );

  final statuses = <String, dynamic>{};
  final logs = <LogEvent>[];

  late final connection = BeeperConnection(
    onStatusUpdate: (String module, dynamic data) {
      setState(() {
        statuses[module] = data;
      });
    },
    onLogEvent: (event) {
      setState(() {
        logs.add(event);
      });
    },
  );

  BeeperInfo? info;

  @override
  void initState() {
    super.initState();
    connection.start().then((v) {
      setState(() {
        info = v;
      });
    });
  }

  @override
  void dispose() {
    connection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Container(
          color: theme.primaryColor,
          width: 1200,
          child: Column(
            children: [
              StatusBar(
                info: info,
                loginState: connection.loginState,
              ),
              BeeperTabBar(
                controller: controller,
                children: const [
                  Text('Status'),
                  Text('Logs'),
                  Text('Commands'),
                ],
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: controller,
                  builder: (BuildContext context, Widget? child) {
                    return Navigator(
                      onPopPage: (route, result) => false,
                      pages: [
                        MaterialPage(
                          child: StatusPage(
                            statuses: statuses,
                            info: info,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusBar extends StatefulWidget {
  const StatusBar({
    Key? key,
    required this.info,
    required this.loginState,
  }) : super(key: key);

  final BeeperInfo? info;
  final ValueListenable<LoginStateDto?> loginState;

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  Timer? timer;
  String? uptime;

  void updateUptime() {
    if (widget.info != null) {
      final now = DateTime.now();
      setState(() {
        uptime = timeString(
          now.difference(widget.info!.started).inMilliseconds / 1000,
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    timer =
        Timer.periodic(const Duration(seconds: 10), (timer) => updateUptime());
  }

  @override
  void didUpdateWidget(StatusBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.info != null && oldWidget.info == null) {
      updateUptime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 16),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  spreadRadius: 4,
                )
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/beeper_small.png',
              width: 32,
              height: 32,
              filterQuality: FilterQuality.low,
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'Beeper Bot'),
                  TextSpan(
                    text: '  -  ',
                    style: TextStyle(
                      color: Colors.white54,
                    ),
                  ),
                  TextSpan(text: 'Console'),
                ],
              ),
              style: GoogleFonts.baloo2(fontSize: 18),
            ),
          ),
          if (uptime != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('version ${widget.info!.version}'),
                  const SizedBox(height: 4),
                  Text('up $uptime'),
                ],
              ),
            ),
          AnimatedBuilder(
            animation: widget.loginState,
            builder: (context, _) {
              final loginState = widget.loginState.value;
              if (loginState == null) {
                return const SizedBox();
              } else if (loginState.signedIn) {
                return Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        spreadRadius: 4,
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/beeper_small.png',
                    width: 32,
                    height: 32,
                    filterQuality: FilterQuality.low,
                  ),
                );
              } else {
                return ElevatedButton(
                  onPressed: () {
                    final signInUri = BeeperConnection.baseUri.replace(
                      path: '/sign_in',
                    );
                    html.window.open('$signInUri', '_self');
                  },
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/discord.png',
                        height: 16,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(width: 8),
                      const Text('Sign In'),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
