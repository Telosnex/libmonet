import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A class for consolidating the definition of menu entries.
///
/// This sort of class is not required, but illustrates one way that defining
/// menus could be done.
class MenuEntry {
  const MenuEntry(
      {required this.label, this.shortcut, this.onPressed, this.menuChildren})
      : assert(menuChildren == null || onPressed == null,
            'onPressed is ignored if menuChildren are provided');
  final String label;

  final MenuSerializableShortcut? shortcut;
  final VoidCallback? onPressed;
  final List<MenuEntry>? menuChildren;

  static List<Widget> build(List<MenuEntry> selections) {
    Widget buildSelection(MenuEntry selection) {
      if (selection.menuChildren != null) {
        return SubmenuButton(
          menuChildren: MenuEntry.build(selection.menuChildren!),
          child: Text(selection.label),
        );
      }
      return MenuItemButton(
        shortcut: selection.shortcut,
        onPressed: selection.onPressed,
        child: Text(selection.label),
      );
    }

    return selections.map<Widget>(buildSelection).toList();
  }

  static Map<MenuSerializableShortcut, Intent> shortcuts(
      List<MenuEntry> selections) {
    final Map<MenuSerializableShortcut, Intent> result =
        <MenuSerializableShortcut, Intent>{};
    for (final MenuEntry selection in selections) {
      if (selection.menuChildren != null) {
        result.addAll(MenuEntry.shortcuts(selection.menuChildren!));
      } else {
        if (selection.shortcut != null && selection.onPressed != null) {
          result[selection.shortcut!] =
              VoidCallbackIntent(selection.onPressed!);
        }
      }
    }
    return result;
  }
}

class MenuBarComponent extends StatefulWidget {
  const MenuBarComponent({
    super.key,
    required this.message,
  });

  final String message;

  @override
  State<MenuBarComponent> createState() => _MenuBarComponentState();
}

class _MenuBarComponentState extends State<MenuBarComponent> {
  ShortcutRegistryEntry? _shortcutsEntry;
  String? _lastSelection;


  bool get showingMessage => _showMessage;
  bool _showMessage = false;
  set showingMessage(bool value) {
    if (_showMessage != value) {
      setState(() {
        _showMessage = value;
      });
    }
  }

  @override
  void dispose() {
    _shortcutsEntry?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            MenuBar(
              children: MenuEntry.build(_getMenus()),
            ),
          ],
        ),
        Text(
          showingMessage ? widget.message : '',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(_lastSelection != null ? 'Last Selected: $_lastSelection' : ''),
      ],
    );
  }

  List<MenuEntry> _getMenus() {
    final List<MenuEntry> result = <MenuEntry>[
      MenuEntry(
        label: 'Menu Demo',
        menuChildren: <MenuEntry>[
          MenuEntry(
            label: 'About',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'MenuBar Sample',
                applicationVersion: '1.0.0',
              );
              setState(() {
                _lastSelection = 'About';
              });
            },
          ),
          MenuEntry(
            label: showingMessage ? 'Hide Message' : 'Show Message',
            onPressed: () {
              setState(() {
                _lastSelection =
                    showingMessage ? 'Hide Message' : 'Show Message';
                showingMessage = !showingMessage;
              });
            },
            shortcut:
                const SingleActivator(LogicalKeyboardKey.keyS, control: true),
          ),
          // Hides the message, but is only enabled if the message isn't
          // already hidden.
          MenuEntry(
            label: 'Reset Message',
            onPressed: showingMessage
                ? () {
                    setState(() {
                      _lastSelection = 'Reset Message';
                      showingMessage = false;
                    });
                  }
                : null,
            shortcut: const SingleActivator(LogicalKeyboardKey.escape),
          ),
          MenuEntry(
            label: 'Background Color',
            menuChildren: <MenuEntry>[
              MenuEntry(
                label: 'Red Background',
                onPressed: () {
              
                },
                shortcut: const SingleActivator(LogicalKeyboardKey.keyR,
                    control: true),
              ),
              MenuEntry(
                label: 'Green Background',
                onPressed: () {
                  setState(() {
        
                  });
                },
                shortcut: const SingleActivator(LogicalKeyboardKey.keyG,
                    control: true),
              ),
              MenuEntry(
                label: 'Blue Background',
                onPressed: () {
                  setState(() {
 
                  });
                },
                shortcut: const SingleActivator(LogicalKeyboardKey.keyB,
                    control: true),
              ),
            ],
          ),
        ],
      ),
    ];
    // (Re-)register the shortcuts with the ShortcutRegistry so that they are
    // available to the entire application, and update them if they've changed.
    _shortcutsEntry?.dispose();
    _shortcutsEntry = null;
    Future.delayed(Duration.zero, () {
      if (context.mounted) {
        try {
          _shortcutsEntry =
              ShortcutRegistry.of(context).addAll(MenuEntry.shortcuts(result));
        } catch (e) {
          // Silence exception, currently the Flutter demo code for MenuBar
          // doesn't work and causes a lot of noise, even with workarounds.
        }
      }
    });

    return result;
  }
}
