import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.width = 220, this.height = 96});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/logo-ac.jpg',
        width: width,
        height: height,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
}

class BrandedTitle extends StatelessWidget {
  const BrandedTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const AppLogo(width: 32, height: 28),
          const SizedBox(width: 8),
          Flexible(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}
