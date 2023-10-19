import 'package:flutter/foundation.dart';

void monetDebug(bool debug, String Function() message) {
  if (debug && kDebugMode) {
    // ignore: avoid_print
    print(message());
  }
}
