
import 'package:flutter/material.dart';

class ChessBoardPainter extends CustomPainter {
  final double squareSize;

  ChessBoardPainter({required this.squareSize});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // calculate the number of squares per row / column
    int n = (size.width ~/ squareSize) + 1;
    bool isWhiteSquare = false;

    Paint paint = Paint();

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (isWhiteSquare) {
          paint.color = Colors.white;
        } else {
          paint.color = Colors.black;
        }
        canvas.drawRect(
          Rect.fromLTWH(i * squareSize, j * squareSize, squareSize, squareSize),
          paint,
        );
        isWhiteSquare = !isWhiteSquare;
      }
      // if there are even number of squares, alternate the starting color in each row
      if (n % 2 == 0) isWhiteSquare = !isWhiteSquare;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
