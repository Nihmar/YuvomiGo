import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottone "Impostazioni" condiviso dalle AppBar dei moduli.
final class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Impostazioni',
      onPressed: () => context.push('/settings'),
    );
  }
}
