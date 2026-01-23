import 'package:flutter/material.dart';

// Simple aligned image preview used in the Event Entry form
class AlignedImagePreview extends StatelessWidget {
  const AlignedImagePreview({
    super.key,
    required this.provider,
    required this.alignY,
  });

  final ImageProvider provider;
  final double alignY;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.cover,
      alignment: Alignment(0, alignY),
      child: Image(image: provider),
    );
  }
}
