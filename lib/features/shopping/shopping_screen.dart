import 'package:flutter/material.dart';
import 'package:yuvomigo/features/home/module_placeholder.dart';

/// Spesa (placeholder): implementato in M2.
final class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      title: 'Spesa',
      icon: Icons.shopping_cart,
      detail: 'Liste di spesa, articoli, check. In arrivo in M2.',
    );
  }
}
