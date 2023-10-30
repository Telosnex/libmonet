
import 'package:flutter/material.dart';

class HorizontalPadding extends StatelessWidget {
  static const rightInset = EdgeInsets.only(right: 8);
  static const leftInset = EdgeInsets.only(left: 8);
  static const inset = EdgeInsets.only(left: 8, right: 8);
  const HorizontalPadding({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: 8,);
  }
}

class  VerticalPadding extends StatelessWidget {
  static const bottomInset = EdgeInsets.only(bottom: 8);
  static const inset = EdgeInsets.symmetric(vertical: 8);
  static const topInset = EdgeInsets.only(top: 8);

  const VerticalPadding({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 8,);
  }
}