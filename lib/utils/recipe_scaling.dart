// lib/utils/recipe_scaling.dart
//
// Client-side ingredient scaling — mirrors the web `scaleIngredient` util.
// Parses the leading quantity of an ingredient line, scales it by a factor, and
// reformats into kitchen-friendly fractions. Lines without a leading number
// (e.g. "salt to taste") are returned unchanged.

const Map<String, double> _unicodeFractions = {
  '¼': 0.25, '½': 0.5, '¾': 0.75,
  '⅓': 1 / 3, '⅔': 2 / 3,
  '⅕': 0.2, '⅖': 0.4, '⅗': 0.6, '⅘': 0.8,
  '⅙': 1 / 6, '⅚': 5 / 6,
  '⅛': 0.125, '⅜': 0.375, '⅝': 0.625, '⅞': 0.875,
};

const String _uni = '¼½¾⅓⅔⅕⅖⅗⅘⅙⅚⅛⅜⅝⅞';

const List<List<dynamic>> _fractionSteps = [
  [0.0, ''],
  [1 / 8, '⅛'], [1 / 4, '¼'], [1 / 3, '⅓'], [3 / 8, '⅜'], [1 / 2, '½'],
  [5 / 8, '⅝'], [2 / 3, '⅔'], [3 / 4, '¾'], [7 / 8, '⅞'], [1.0, ''],
];

double? _parseQty(String token) {
  final t = token.trim();
  if (t.length == 1 && _unicodeFractions.containsKey(t)) return _unicodeFractions[t];

  var m = RegExp('^(\\d+)\\s*([$_uni])\$').firstMatch(t); // "1½"
  if (m != null) return int.parse(m.group(1)!) + _unicodeFractions[m.group(2)!]!;

  m = RegExp(r'^(\d+)\s+(\d+)/(\d+)$').firstMatch(t); // "1 1/2"
  if (m != null) {
    return int.parse(m.group(1)!) +
        int.parse(m.group(2)!) / int.parse(m.group(3)!);
  }

  m = RegExp(r'^(\d+)/(\d+)$').firstMatch(t); // "1/2"
  if (m != null) return int.parse(m.group(1)!) / int.parse(m.group(2)!);

  final n = double.tryParse(t); // "2", "1.5"
  return n;
}

/// Format a number as a kitchen-friendly amount: 3.25 → "3¼", 0.5 → "½", 3 → "3".
String formatQty(double value) {
  if (!value.isFinite || value <= 0) return '0';
  var whole = value.floor();
  final rem = value - whole;

  List<dynamic> best = _fractionSteps[0];
  double bestDiff = double.infinity;
  for (final f in _fractionSteps) {
    final d = (rem - (f[0] as double)).abs();
    if (d < bestDiff) {
      bestDiff = d;
      best = f;
    }
  }
  var frac = best[1] as String;
  if ((best[0] as double) == 1.0) {
    whole += 1;
    frac = '';
  }

  if (whole == 0 && frac.isEmpty) {
    final rounded = (value * 100).round() / 100;
    return rounded.toString();
  }
  if (whole == 0) return frac;
  return frac.isNotEmpty ? '$whole$frac' : whole.toString();
}

final RegExp _leadingQty = RegExp(
  '^(\\s*)('
  '(?:\\d+\\s+\\d+/\\d+|\\d+\\s*[$_uni]|\\d+/\\d+|\\d*\\.\\d+|\\d+|[$_uni])'
  ')(\\s*(?:-|–|—|to)\\s*('
  '(?:\\d+\\s+\\d+/\\d+|\\d+\\s*[$_uni]|\\d+/\\d+|\\d*\\.\\d+|\\d+|[$_uni])'
  '))?',
);

/// Scale the leading quantity of an ingredient line by [factor], keeping the unit
/// and item text untouched. Handles fractions, mixed numbers, decimals and ranges.
String scaleIngredient(String line, double factor) {
  if (!factor.isFinite || factor <= 0 || (factor - 1).abs() < 1e-9) return line;

  final m = _leadingQty.firstMatch(line);
  if (m == null) return line;

  final leadWs = m.group(1) ?? '';
  final low = _parseQty(m.group(2)!);
  if (low == null) return line;

  final rest = line.substring(m.end);

  final highStr = m.group(4);
  if (highStr != null) {
    final high = _parseQty(highStr);
    if (high == null) return line;
    return '$leadWs${formatQty(low * factor)}–${formatQty(high * factor)}$rest';
  }
  return '$leadWs${formatQty(low * factor)}$rest';
}

/// Scale a whole ingredient list by the factor (newServings / originalServings).
List<String> scaleIngredients(List<String> ingredients, double factor) {
  return ingredients.map((i) => scaleIngredient(i, factor)).toList();
}
