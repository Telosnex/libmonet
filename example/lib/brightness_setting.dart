import 'package:flutter/material.dart';

enum BrightnessSetting {
  light,
  dark,
  auto;

  String get label => switch (this) {
        BrightnessSetting.light => 'Light',
        BrightnessSetting.dark => 'Dark',
        BrightnessSetting.auto => 'Auto',
      };

  IconData get icon => switch (this) {
        BrightnessSetting.light => Icons.light_mode,
        BrightnessSetting.dark => Icons.dark_mode,
        BrightnessSetting.auto => Icons.brightness_auto,
      };

  Brightness brightness(BuildContext context) => switch (this) {
        BrightnessSetting.light => Brightness.light,
        BrightnessSetting.dark => Brightness.dark,
        BrightnessSetting.auto => MediaQuery.platformBrightnessOf(context),
      };
}
