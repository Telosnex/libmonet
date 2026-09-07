import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:libmonet/shapes/material_expressive_shape.dart';

const _source = 'androidx.compose.material3:material3:1.5.0-alpha27';
const _coordinateOrder = [
  'anchor0X',
  'anchor0Y',
  'control0X',
  'control0Y',
  'control1X',
  'control1Y',
  'anchor1X',
  'anchor1Y',
];

void main() {
  test('every Material shape cubic matches the AndroidX reference', () {
    final fixture = jsonDecode(
      File('test/shapes/fixtures/material_shapes_androidx.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(fixture['source'], _source);
    expect(fixture['coordinateOrder'], _coordinateOrder);

    final reference = fixture['shapes'] as Map<String, dynamic>;
    expect(
      reference.keys.toSet(),
      MaterialExpressiveShape.values.map((it) => it.name).toSet(),
    );

    // AndroidX computes in Float while the Dart port computes in double. The
    // epsilon covers only that precision difference; ordering and cubic counts
    // must match exactly.
    const epsilon = 5e-6;
    for (final shape in MaterialExpressiveShape.values) {
      final expectedCubics = reference[shape.name] as List<dynamic>;
      final actualCubics = shape.polygon.cubics;
      expect(
        actualCubics,
        hasLength(expectedCubics.length),
        reason: '${shape.name} cubic count',
      );
      for (var cubicIndex = 0; cubicIndex < actualCubics.length; cubicIndex++) {
        final cubic = actualCubics[cubicIndex];
        final actual = [
          cubic.anchor0X,
          cubic.anchor0Y,
          cubic.control0X,
          cubic.control0Y,
          cubic.control1X,
          cubic.control1Y,
          cubic.anchor1X,
          cubic.anchor1Y,
        ];
        final expected = (expectedCubics[cubicIndex] as List<dynamic>)
            .cast<num>();
        expect(expected, hasLength(_coordinateOrder.length));
        for (var coordinate = 0; coordinate < actual.length; coordinate++) {
          expect(
            actual[coordinate],
            closeTo(expected[coordinate], epsilon),
            reason:
                '${shape.name} cubic $cubicIndex ${_coordinateOrder[coordinate]}',
          );
        }
      }
    }
  });
}
