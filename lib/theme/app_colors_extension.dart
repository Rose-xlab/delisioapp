import 'package:flutter/material.dart';

@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color gray500;
  final Color gray200;
  final Color borderLight;

  const AppColorsExtension({
    required this.gray500,
    required this.gray200,
    required this.borderLight,
  });

  @override
  AppColorsExtension copyWith({Color? gray500, Color? gray200}) {
    return AppColorsExtension(
      gray500: gray500 ?? this.gray500,
      gray200: gray200 ?? this.gray200,
      borderLight: borderLight ?? this.borderLight,
    );
  }

  @override
  AppColorsExtension lerp(ThemeExtension<AppColorsExtension>? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      gray500: Color.lerp(gray500, other.gray500, t)!,
      gray200: Color.lerp(gray200, other.gray200, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
    );
  }
}
