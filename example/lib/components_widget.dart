import 'package:monet_studio/menu_bar_component.dart';
import 'package:monet_studio/padding.dart';
import 'package:monet_studio/tab_bar_component.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/theming/button_style.dart';
import 'package:libmonet/theming/monet_theme.dart';

class H3 extends ConsumerWidget {
  final String text;
  const H3(this.text, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(text, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}

class ComponentsWidget extends HookConsumerWidget {
  const ComponentsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monetTheme = MonetTheme.of(context);
    final switchValue = useState(false);
    final sliderValue = useState(0.5);
    final choiceChipSelected = useState(false);
    final filterChipSelected = useState(false);
    final radioValue = useState<int?>(0);
    final checkboxValue = useState(false);
    final navigationBarSelectedValue = useState<int>(0);
    final navigationRailSelectedValue = useState<int>(0);
    final bottomNavBarSelectedValue = useState<int>(0);

    onRadioValueChanged(int? value) {
      radioValue.value = value;
    }

    final segmentedButtonSelected = useState<Set<int>>({0});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const H3('Badge'),
        const Row(
          children: [
            Badge(
              child: Text('Badge'),
            ),
            HorizontalPadding(),
            Badge(
              label: Text('Badge Text'),
              child: Text('Badge'),
            ),
          ],
        ),
        const H3('Chip'),
        Row(
          children: [
            const Chip(
              avatar: CircleAvatar(
                child: Text('AB'),
              ),
              label: Text('Chip'),
            ),
            const HorizontalPadding(),
            InputChip(
              label: const Text('Input Chip'),
              onSelected: (_) {},
            ),
            const HorizontalPadding(),
            ChoiceChip(
              label: const Text('Choice Chip'),
              selected: choiceChipSelected.value,
              onSelected: (value) {
                choiceChipSelected.value = value;
              },
            ),
            const HorizontalPadding(),
            FilterChip(
              label: const Text('Filter Chip'),
              selected: filterChipSelected.value,
              onSelected: (value) {
                filterChipSelected.value = value;
              },
            ),
          ],
        ),
        const H3('Banner'),
        MaterialBanner(content: const Text('Banner'), actions: [
          TextButton.icon(
            onPressed: () {},
            style: fillButtonStyle(monetTheme.primary),
            label: const Text('Action'),
            icon: const Icon(Icons.abc),
          ),
          TextButton.icon(
            onPressed: () {},
            style: fillButtonStyle(monetTheme.primary),
            label: const Text('Another action'),
            icon: const Icon(Icons.ac_unit),
          ),
        ]),
        const H3('BottomAppBar'),
        BottomAppBar(
          child: Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.menu),
              ),
              const Spacer(), // spacer to distribute space evenly
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
        const H3('ButtonBar'),
        OverflowBar(children: <Widget>[
          TextButton.icon(
            label: const Text('Label'),
            icon: const Icon(Icons.abc),
            onPressed: () {},
          ),
          TextButton.icon(
            label: const Text('Another label'),
            icon: const Icon(Icons.ac_unit),
            onPressed: () {},
          )
        ]),
        const H3('Card'),
        const Card(
            child: SizedBox(width: 160, height: 160, child: Text('Card'))),
        const H3('Checkbox'),
        Row(
          children: [
            Checkbox(
                value: checkboxValue.value,
                onChanged: (bool? value) {
                  checkboxValue.value = value ?? false;
                }),

          ],
        ),
        const H3('Data Table'),
        DataTable(
          columns: const <DataColumn>[
            DataColumn(
              label: Text(
                'ID',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            DataColumn(
              label: Text(
                'Name',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            DataColumn(
              label: Text(
                'Role',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
          ],
          rows: const <DataRow>[
            DataRow(
              cells: <DataCell>[
                DataCell(Text('1')),
                DataCell(Text('Amanda')),
                DataCell(Text('Team Lead')),
              ],
            ),
            DataRow(
              cells: <DataCell>[
                DataCell(Text('2')),
                DataCell(Text('James')),
                DataCell(Text('Developer')),
              ],
            ),
            DataRow(
              cells: <DataCell>[
                DataCell(Text('3')),
                DataCell(Text('Sophie')),
                DataCell(Text('Designer')),
              ],
            ),
          ],
        ),
        const H3('Date Picker'),
        TextButton(
          child: const Text('Show Date Picker'),
          onPressed: () => showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2001),
            lastDate: DateTime(2101),
          ),
        ),
        const H3('Dialog'),
        TextButton(
          onPressed: () => showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('DialogTitle'),
                content: const Text('Dialog body!'),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'Cancel'),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, 'OK'),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          ),
          child: const Text('Show Dialog'),
        ),
        const H3('Divider'),
        const Divider(),
        const H3('Elevated Button'),
        ElevatedButton(onPressed: () {}, child: const Text('Elevated Button')),
        const H3('Expansion Tile'),
        const ExpansionTile(title: Text('Expansion Tile'), children: <Widget>[
          ListTile(title: Text('ListTile in ExpansionTile'))
        ]),
        const H3('FilledButton'),
        FilledButton(onPressed: () {}, child: const Text('Filled Button')),
        const H3('Floating Action Button'),
        FloatingActionButton(
            onPressed: () {}, child: const Icon(Icons.navigation)),
        const H3('Icon Button'),
        IconButton(
            icon: const Icon(Icons.volunteer_activism), onPressed: () {}),
        const H3('List Tile'),
        const ListTile(
          title: Text('List Tile Title'),
          subtitle: Text('Subtitle'),
          leading: Icon(Icons.abc),
          trailing: Icon(Icons.ac_unit),
        ),
        const H3('Menu Bar'),
        const SizedBox(
            height: 120, child: MenuBarComponent(message: 'Hello, world!')),
        const H3('Menu Button'),
        PopupMenuButton(
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(child: Text('Item 1')),
            const PopupMenuItem(child: Text('Item 2')),
          ],
        ),
        const H3('Navigation Bar'),
        NavigationBar(
          onDestinationSelected: (value) {
            navigationBarSelectedValue.value = value;
          },
          selectedIndex: navigationBarSelectedValue.value,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.business),
              label: 'Business',
            ),
            NavigationDestination(
              icon: Icon(Icons.school),
              label: 'School',
            ),
          ],
        ),
        const H3('Bottom Navigation Bar'),
        BottomNavigationBar(
          currentIndex: bottomNavBarSelectedValue.value,
          onTap: (int index) {
            bottomNavBarSelectedValue.value = index;
          },
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.business),
              label: 'Business',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: 'School',
            ),
          ],
        ),
        const H3('Navigation Rail'),
        SizedBox(
          height: 160,
          child: NavigationRail(
            selectedIndex: navigationRailSelectedValue.value,
            onDestinationSelected: (int index) {
              navigationRailSelectedValue.value = index;
            },
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: Text('First'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.bookmark_border),
                selectedIcon: Icon(Icons.book),
                label: Text('Second'),
              ),
            ],
          ),
        ),
        const H3('Outlined Button'),
        OutlinedButton(onPressed: () {}, child: const Text('Outlined Button')),
        const H3('Progress Indicator'),
        const CircularProgressIndicator(),
        const VerticalPadding(),
        const LinearProgressIndicator(
          value: 0.66,
        ),
        const VerticalPadding(),
        const LinearProgressIndicator(),
   
        const H3('Radio'),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Radio(
              value: 0,
              groupValue: radioValue.value,
              onChanged: onRadioValueChanged,
            ),
            const Text('Zero'),
            Radio(
              value: 1,
              groupValue: radioValue.value,
              onChanged: onRadioValueChanged,
            ),
            const Text('One'),
            Radio(
              value: 2,
              groupValue: radioValue.value,
              onChanged: onRadioValueChanged,
            ),
            const Text('Two'),
          ],
        ),
        const H3('Search Bar'),
        const SearchBar(
          leading: Icon(
            Icons.search,
          ),
        ),
        const H3('Segmented Button'),
        SegmentedButton(
          segments: const [
            ButtonSegment(value: 0, label: Text('Label')),
            ButtonSegment(value: 1, label: Text('Another Label')),
          ],
          selected: segmentedButtonSelected.value,
          onSelectionChanged: (newValues) {
            segmentedButtonSelected.value = newValues;
          },
        ),
        const H3('Slider'),
        Slider(
            value: sliderValue.value,
            onChanged: (double value) {
              sliderValue.value = value;
            }),
        const H3('Snackbar'),
        TextButton(
          child: const Text('Show Snackbar'),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(

              content: Text('Hello, Snackbar'),
            ));
          },
        ),
        const H3('Switch'),
        Switch(
            value: switchValue.value,
            onChanged: (bool value) {
              switchValue.value = value;
            }),
        const H3('Tab Bar'),
        const TabBarComponent(),
        const H3('Text Button'),
        TextButton(onPressed: () {}, child: const Text('Text Button')),
        const H3('Text Selection'),
        const TextField(),
        const H3('Tooltip'),
        const Tooltip(message: 'Hello Tooltip', child: Icon(Icons.info)),
        const H3('Time Picker'),
        TextButton(
          child: const Text('Show Time Picker'),
          onPressed: () =>
              showTimePicker(context: context, initialTime: TimeOfDay.now()),
        ),
        const H3('Toggle Buttons'),
        ToggleButtons(
          isSelected: const [true, false],
          onPressed: (_) {},
          children: const <Widget>[Icon(Icons.ac_unit), Icon(Icons.call)],
        ),
      ],
    );
  }
}
