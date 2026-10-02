import 'package:flutter/material.dart';

/// Date stamp printed on the Polaroid. Uses a bundled typewriter typeface so
/// it renders identically in previews and exports.
class DateStamp extends StatelessWidget {
  const DateStamp({
    super.key,
    required this.text,
    required this.width,
    required this.color,
    this.align = TextAlign.right,
  });

  final String text;
  final double width;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Date stamp: $text',
      child: Align(
        alignment: align == TextAlign.left
            ? Alignment.centerLeft
            : Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            textAlign: align,
            style: TextStyle(
              fontFamily: 'SpecialElite',
              fontSize: width * 0.037,
              height: 1.1,
              letterSpacing: width * 0.0045,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
