import 'package:flutter/material.dart';

class BeeperTabBar extends StatelessWidget {
  const BeeperTabBar({
    Key? key,
    required this.controller,
    required this.children,
  }) : super(key: key);

  final TabController controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 2)),
      ),
      width: double.infinity,
      child: Wrap(
        spacing: 4.0,
        children: [
          for (var i = 0; i < children.length; i++)
            BeeperTab(
              controller: controller,
              index: i,
              child: children[i],
            ),
        ],
      ),
    );
  }
}

class BeeperTab extends StatelessWidget {
  const BeeperTab({
    Key? key,
    required this.controller,
    required this.index,
    required this.child,
  }) : super(key: key);

  final TabController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final theme = Theme.of(context);
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: controller.index == index
                    ? theme.colorScheme.secondary
                    : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: TextButton(
            style: ButtonStyle(
              shape: MaterialStateProperty.all(
                const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8.0),
                  ),
                ),
              ),
            ),
            onPressed: () {
              controller.index = index;
            },
            child: child,
          ),
        );
      },
    );
  }
}
