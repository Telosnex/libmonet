import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class TabBarComponent extends HookConsumerWidget {
  const TabBarComponent({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabBarController = useTabController(initialLength: 3);
    return Column(children: [
      TabBar(
        controller: tabBarController,
        tabs: const [
          Tab(icon: Icon(Icons.directions_car)),
          Tab(icon: Icon(Icons.directions_transit)),
          Tab(icon: Icon(Icons.directions_bike)),
        ],
      ),
    ]);
  }
}
