// Copyright 2021 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:ui';

import 'package:libmonet/core/hex_codes.dart';
import 'package:matcher/matcher.dart';

Matcher isColor(dynamic color) => _ColorMatcher(color);

class _ColorMatcher extends Matcher {
  _ColorMatcher(this._argb);

  final dynamic _argb;

  @override
  bool matches(dynamic object, Map<dynamic, dynamic> matchState) {
    if (object is! int && object is! Color) {
      return false;
    }
    if (object is Color && _argb is int) {
      return object.argb == _argb;
    } else if (object is int && _argb is Color) {
      return object == _argb.value;
    }
    return object == _argb;
  }

  @override
  Description describe(Description description) {
    return description.add('color equals ${hexFromArgb(_argb)}');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    return mismatchDescription
        .add('expected hex code\n  ')
        .add(hexFromArgb(_argb))
        .add('\nbut got\n  ')
        .add(hexFromArgb(item is Color ? item.argb : item as int));
  }
}