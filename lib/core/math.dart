// Modified and maintained by open-source contributors, on behalf of libmonet.
//
// Original notice:
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

/// Returns 1 if num > 0, -1 if num < 0, and 0 if num = 0
int signum(double num) {
  if (num < 0) {
    return -1;
  } else if (num == 0) {
    return 0;
  } else {
    return 1;
  }
}

/// Linear interpolation between [start] and [stop] by [amount].
/// [amount] between 0 and 1, inclusive.
double lerp(double start, double stop, double amount) {
  assert(amount >= 0.0 && amount <= 1.0);
  return (1.0 - amount) * start + amount * stop;
}
