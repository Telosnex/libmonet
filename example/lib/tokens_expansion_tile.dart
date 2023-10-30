import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:libmonet/apca.dart';
import 'package:libmonet/contrast.dart';
import 'package:libmonet/hct.dart';
import 'package:libmonet/hex_codes.dart';
import 'package:libmonet/theming/monet_theme.dart';
import 'package:libmonet/wcag.dart';

class TokensExpansionTile extends ConsumerWidget {
  const TokensExpansionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monetTheme = MonetTheme.of(context);
    final primaryColors = monetTheme.primary;
    final algo = monetTheme.algo;
    return ExpansionTile(
      title: Text(
        'Tokens',
        style: Theme.of(context)
            .textTheme
            .headlineLarge!
            .copyWith(color: primaryColors.text),
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: DividerTheme(
            data: DividerThemeData(
              color: monetTheme.secondary.fill,
            ),
            child: SizedBox(
              width: double.infinity,
              child: DataTable(columns: const [
                DataColumn(label: Text('Name')),
                    
                DataColumn(label: Text('')),
                DataColumn(label: Text('Hex'), numeric: true),
                DataColumn(label: Text('H'), numeric: true),
                DataColumn(label: Text('C'), numeric: true),
                DataColumn(label: Text('T'), numeric: true),
                DataColumn(label: Text('K'), numeric: true),
              ], rows: [
                DataRow(
                  cells: _colorCells(
                      context, primaryColors.background, 'BG', null),
                ),
                DataRow(
                  cells: _colorCells(
                    context,
                    primaryColors.backgroundText,
                    'BG Text',
                    _contrast(
                      fg: primaryColors.backgroundText,
                      bg: primaryColors.background,
                      algo: algo,
                    ),
                  ),
                ),
                DataRow(
                  cells: _colorCells(
                    context,
                    primaryColors.colorBorder,
                    'Color Border',
                    _contrast(
                      fg: primaryColors.colorBorder,
                      bg: primaryColors.background,
                      algo: algo,
                    ),
                  ),
                ),
                DataRow(
                  cells: _colorCells(
                    context,
                    primaryColors.color,
                    'Color',
                    _contrast(
                      fg: primaryColors.color,
                      bg: primaryColors.background,
                      algo: algo,
                    ),
                  ),
                ),
                DataRow(
                  cells: _colorCells(
                    context,
                    primaryColors.colorText,
                    'Color Text',
                    _contrast(
                      fg: primaryColors.colorText,
                      bg: primaryColors.color,
                      algo: algo,
                    ),
                  ),
                ),
                DataRow(
                  cells: _colorCells(
                    context,
                    primaryColors.fill,
                    'Fill',
                    _contrast(
                      fg: primaryColors.fill,
                      bg: primaryColors.background,
                      algo: algo,
                    ),
                  ),
                ),
                DataRow(
                  cells: _colorCells(
                    context,
                    primaryColors.fillText,
                    'Fill Text',
                    _contrast(
                      fg: primaryColors.fillText,
                      bg: primaryColors.fill,
                      algo: algo,
                    ),
                  ),
                ),
                DataRow(
                  cells: _colorCells(
                    context,
                    primaryColors.text,
                    'Text',
                    _contrast(
                      fg: primaryColors.text,
                      bg: primaryColors.background,
                      algo: algo,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        )
      ],
    );
  }

  double _contrast({required Color fg, required Color bg, required Algo algo}) {
    return switch (algo) {
      (Algo.apca) =>
        apcaFromColors(textColor: fg, backgroundColor: bg).roundToDouble(),
      (Algo.wcag21) => wcagFromColors(fg, bg)
    };
  }

  List<DataCell> _colorCells(
    BuildContext context,
    Color color,
    String name,
    double? contrast,
  ) {
    final hct = Hct.fromColor(color);
    final colorHeight = DataTableTheme.of(context).dataRowMinHeight! - 8.0;
    return [

      DataCell(
        Text(
          name,
        ),
      ),
      DataCell(Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
        width: colorHeight,
        height: colorHeight,
      )),
      DataCell(
        FittedBox(child: Text(hexFromColor(color))),
      ),
      DataCell(
        Text(
          hct.hue.round().toString().padLeft(3),
          maxLines: 1,
        ),
      ),
      DataCell(
        FittedBox(
          child: Text(
            hct.chroma.round().toString(),
            maxLines: 1,
          ),
        ),
      ),
      DataCell(
        FittedBox(
            child: Text(
          hct.tone.round().toString(),
          maxLines: 1,
        )),
      ),
      DataCell(
        (contrast == null)
            ? Container()
            : FittedBox(
                child: Text(
                  contrast > 21 ||
                          contrast <
                              0 /* i.e. def not WCAG 2.1 or contrast ratio */
                      ? contrast.round().toString()
                      : contrast.toStringAsFixed(1),
                  maxLines: 1,
                ),
              ),
      ),
    ];
  }
}
