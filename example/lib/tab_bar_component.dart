import 'package:material_ui/material_ui.dart';

class TabBarComponent extends StatelessWidget {
  const TabBarComponent({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 3,
      child: Column(children: [
        TabBar(
          tabs: [
            Tab(icon: Icon(Icons.directions_car)),
            Tab(icon: Icon(Icons.directions_transit)),
            Tab(icon: Icon(Icons.directions_bike)),
          ],
        ),
      ]),
    );
  }
}
