import 'dart:typed_data';

import 'package:flutter/material.dart';

class UserPhoto extends StatefulWidget {
  const UserPhoto({
    super.key,
    required this.load,
    required this.placeholder,
    required this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.semanticLabel,
  });

  final Future<Uint8List?> Function() load;
  final Widget placeholder;
  final double height;
  final double? width;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  State<UserPhoto> createState() => _UserPhotoState();
}

class _UserPhotoState extends State<UserPhoto> {
  late final _photo = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: _photo,
    builder: (context, snapshot) {
      final bytes = snapshot.data;
      if (bytes == null || bytes.isEmpty) return widget.placeholder;
      return Image.memory(
        bytes,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (_, _, _) => widget.placeholder,
      );
    },
  );
}
