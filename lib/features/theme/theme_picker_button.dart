import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/features/theme/theme_controller.dart';

/// Bottone palette che apre il dialogo di scelta del colore tema.
final class ThemePickerButton extends ConsumerWidget {
  const ThemePickerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.palette_outlined),
      tooltip: 'Cambia tema',
      onPressed: () => showDialog<void>(
        context: context,
        builder: (_) => const _ThemePickerDialog(),
      ),
    );
  }
}

final class _ThemePickerDialog extends ConsumerWidget {
  const _ThemePickerDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(themeControllerProvider);
    return AlertDialog(
      title: const Text('Scegli il colore'),
      content: SizedBox(
        width: double.maxFinite,
        child: RadioGroup<int>(
          groupValue: selected,
          onChanged: (seed) async {
            if (seed == null) return;
            await ref.read(themeControllerProvider.notifier).select(seed);
            if (context.mounted) Navigator.of(context).pop();
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final choice in themeChoices)
                RadioListTile<int>(
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(choice.seed),
                      ),
                      const SizedBox(width: 12),
                      Text(choice.name),
                    ],
                  ),
                  value: choice.seed,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
