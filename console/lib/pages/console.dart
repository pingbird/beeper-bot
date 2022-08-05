import 'dart:async';
import 'dart:html' as html;

import 'package:admin2/components/tabs.dart';
import 'package:admin2/pages/status.dart';
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
    length: 1,
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
  final dropdownButtonKey = GlobalKey();
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

  void showDropdown() {
    final navigator = Navigator.of(context);
    final buttonRenderObject =
        dropdownButtonKey.currentContext!.findRenderObject() as RenderBox;
    final navigatorRenderObject = navigator.context.findRenderObject()!;
    navigator.push(
      _DropdownRoute(
        builder: (context) => _Dropdown(loginState: widget.loginState),
        anchor: buttonRenderObject.localToGlobal(
          buttonRenderObject.size.bottomRight(Offset.zero),
          ancestor: navigatorRenderObject,
        ),
        buttonHeight: buttonRenderObject.size.height,
      ),
    );
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
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: showDropdown,
                    child: Container(
                      key: dropdownButtonKey,
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
                      child: Image.network(
                        loginState.avatar!,
                        width: 48,
                        height: 48,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
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

class _DropdownRoute<T> extends PopupRoute<T> {
  _DropdownRoute({
    required this.builder,
    required this.anchor,
    required this.buttonHeight,
  });

  final WidgetBuilder builder;
  final Offset anchor;
  final double buttonHeight;

  @override
  Color? get barrierColor => Colors.black12;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: anchor.dy,
              right: constraints.maxWidth - anchor.dx,
              bottom: 0,
              child: Align(
                alignment: Alignment.topRight,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final curvedAnimation = CurvedAnimation(
                      parent: animation,
                      curve: Curves.ease,
                    );
                    return Opacity(
                      opacity: curvedAnimation.value,
                      child: ClipPath(
                        clipper: _AnimatedClipper(
                          curvedAnimation.value,
                          buttonHeight,
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: builder(context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);
}

class _AnimatedClipper extends CustomClipper<Path> {
  _AnimatedClipper(this.dt, this.buttonHeight);

  final double dt;
  final double buttonHeight;

  @override
  Path getClip(Size size) {
    final buttonRadius = buttonHeight / 2;
    final center = Offset(size.width - buttonRadius, -buttonRadius);
    final bottomLeft = size.bottomLeft(Offset.zero);
    return Path()
      ..addOval(
        Rect.fromCircle(
          center: center,
          radius: buttonRadius + (bottomLeft - center).distance * dt,
        ),
      );
  }

  @override
  bool shouldReclip(_AnimatedClipper oldClipper) => dt != oldClipper.dt;
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({
    Key? key,
    required this.loginState,
  }) : super(key: key);

  final ValueListenable<LoginStateDto?> loginState;

  @override
  Widget build(BuildContext context) {
    final loginState = this.loginState.value;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 300,
      decoration: BoxDecoration(
        color: Color.alphaBlend(Colors.black12, const Color(0xff252729)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            spreadRadius: 4,
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: const Color(0xff252729),
              alignment: Alignment.centerRight,
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Hello, '),
                    TextSpan(
                      text: '${loginState?.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: '#${loginState?.discriminator}',
                      style: const TextStyle(
                        color: Color(0xffc9c9c9),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                style: GoogleFonts.baloo2(fontSize: 16),
              ),
            ),
            TextButton(
              style: ButtonStyle(
                shape: MaterialStateProperty.all(
                  const RoundedRectangleBorder(),
                ),
              ),
              onPressed: () {
                final signOutUri = BeeperConnection.baseUri.replace(
                  path: '/sign_out',
                );
                html.window.location.assign('$signOutUri');
              },
              child: const Align(
                alignment: Alignment.centerRight,
                child: Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
