#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fixture="$repo_root/test/shapes/fixtures/material_shapes_androidx.json"
project="$repo_root/tool/material_shapes_reference"

"$project/gradlew" --no-daemon -p "$project" run --args="$fixture"

echo "Verify the generated fixture with:"
echo "  flutter test test/shapes/material_shapes_androidx_parity_test.dart"
